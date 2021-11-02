#include <string.h>
#include "serial_relay.h"

#define PORT_BUFFER_SIZE 1024

// Simple macro to print only if DEBUG is defined
#define debug_print(fmt, ...)                  \
    do                                         \
    {                                          \
        if (DEBUG)                             \
            fprintf(stderr, fmt, __VA_ARGS__); \
    } while (0)

// Helper functions to check each zmq/serial function executes correctly
enum sr_return check_serial(enum sp_return ret_val);
enum sr_return check_zmq(int rc);


// Opaque struct to hold useful serial relay stuff
typedef struct _serial_zmq_relay
{
    // Setup serial port struct
    struct sp_port *port;
    // ZMQ context
    void *context;
    // Socket which Mercury will message to (this is subscribing socket)
    void *serial_sub_socket;
    // Buffer used for recieving dumping serial port buffer into publisher
    uint8_t *msg_sub_buffer;
    // Socket which Mercury will listen to (this is publishing socket)
    void *serial_pub_socket;
    // Buffer used for recieving dumping serial port buffer into publisher
    uint8_t *msg_pub_buffer;
} serial_zmq_relay;


void *open_relay(const char *port_name,
                 int baudrate,
                 const char *sub_endpoint,
                 const char *pub_endpoint)
{
    // Result check ints
    enum sr_return flag;
    int conflate = 1;

    // Allocate memory for relay object
    serial_zmq_relay *relay = calloc(1, sizeof(serial_zmq_relay));
    if (relay == NULL)
    {
        fprintf(stderr, "Failed to allocate serial_zmq_relay object!\n");
        goto fail_relay_calloc;
    }

    // ***************** Initialize Pointers *****************
    // Setup the serial ports
    flag = check_serial(sp_get_port_by_name(port_name, &(relay->port)));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to find serial port by name %s!\n", port_name);
        goto fail_port_name;
    }
    flag = check_serial(sp_open(relay->port, SP_MODE_READ_WRITE));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to open serial port %s!\n", port_name);
        goto fail_sp_open;
    }
    flag = check_serial(sp_set_baudrate(relay->port, baudrate));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to set serial port baudrate to %d!\n", baudrate);
        goto fail_set_baudrate;
    }

    // Setup the serial port in/out buffers
    relay->msg_sub_buffer = (uint8_t *)calloc(PORT_BUFFER_SIZE, sizeof(uint8_t));
    if (relay->msg_sub_buffer == NULL)
    {
        fprintf(stderr, "Failed to allocate serial subscirber buffer!\n");
        goto fail_sub_buffer;
    }
    relay->msg_pub_buffer = (uint8_t *)calloc(PORT_BUFFER_SIZE, sizeof(uint8_t));
    if (relay->msg_pub_buffer == NULL)
    {
        fprintf(stderr, "Failed to allocate serial publisher buffer!\n");
        goto fail_pub_buffer;
    }

    // Setup the zmq ports
    relay->context = zmq_ctx_new();
    if (relay->context == NULL)
    {
        fprintf(stderr, "Failed to create new ZMQ context!\n");
        goto fail_context;
    }
    relay->serial_pub_socket = zmq_socket(relay->context, ZMQ_PUB);
    if (relay->serial_pub_socket == NULL)
    {
        fprintf(stderr, "Failed to create ZMQ publisher socket!\n");
        goto fail_pub_socket;
    }
    relay->serial_sub_socket = zmq_socket(relay->context, ZMQ_SUB);
    if (relay->serial_sub_socket == NULL)
    {
        fprintf(stderr, "Failed to create ZMQ subscriber socket!\n");
        goto fail_sub_socket;
    }

    // Setup serial subscriber, also set conflate option
    flag = check_zmq(zmq_setsockopt(relay->serial_sub_socket, ZMQ_SUBSCRIBE, "", 0));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to set socket to subscriber!\n");
        goto fail_sub_setsockopt;
    }
    flag = check_zmq(zmq_setsockopt(relay->serial_sub_socket, ZMQ_CONFLATE, &conflate, sizeof(conflate)));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to set subscriber conflate option!\n");
        goto fail_sub_setsockopt;
    }
    flag = check_zmq(zmq_connect(relay->serial_sub_socket, sub_endpoint));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to connect ZMQ subscriber to port: %s!\n", sub_endpoint);
        goto fail_sub_connect;
    }

    // Set conflate option for serial publisher
    flag = check_zmq(zmq_setsockopt(relay->serial_pub_socket, ZMQ_CONFLATE, &conflate, sizeof(conflate)));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to set publisher conflate option!\n");
        goto fail_pub_setsockopt;
    }
    flag = check_zmq(zmq_bind(relay->serial_pub_socket, pub_endpoint));
    if (flag != SR_OK)
    {
        fprintf(stderr, "Failed to bind ZMQ publisher to port %s\n", pub_endpoint);
        goto fail_pub_bind;
    }

    return relay;

fail_pub_bind:;
fail_pub_setsockopt:;
fail_sub_connect:;
fail_sub_setsockopt:;
    zmq_close(relay->serial_sub_socket);
fail_sub_socket:;
    zmq_close(relay->serial_pub_socket);
fail_pub_socket:;
    zmq_ctx_destroy(relay->context);
fail_context:;
    free(relay->msg_pub_buffer);
fail_pub_buffer:;
    free(relay->msg_sub_buffer);
fail_sub_buffer:;
fail_set_baudrate:;
    sp_close(relay->port);
    sp_free_port(relay->port);
fail_sp_open:;
fail_port_name:;
    free(relay);
fail_relay_calloc:;
    return NULL;
}


enum sr_return _relay_read(serial_zmq_relay *relay)
{
    enum sr_return flag;

    // Check how many bytes are avalible from the serial port and read them in
    int bytes_waiting = sp_input_waiting(relay->port);
    flag = check_serial(bytes_waiting);
    if (flag != SR_OK) return flag;

    if (bytes_waiting > 0)
    {
        int bytes_read = sp_blocking_read(relay->port,
                                          (void *)relay->msg_pub_buffer,
                                          bytes_waiting,
                                          (unsigned int)1000);
        flag = check_serial(bytes_read);
        if (flag != SR_OK) return flag;
        debug_print("Read %d bytes: %.*s\n", bytes_read, bytes_read, relay->msg_pub_buffer);

        // Construct zmq message and copy data from buffer
        zmq_msg_t msg;
        size_t msg_size = bytes_read;
        flag = check_zmq(zmq_msg_init_size(&msg, msg_size));
        if (flag != SR_OK) return flag;

        memcpy(zmq_msg_data(&msg), relay->msg_pub_buffer, msg_size);

        // Relay those bytes through zmq
        flag = check_zmq(zmq_msg_send(&msg, relay->serial_pub_socket, 0));
        if (flag != SR_OK) return flag;
    }

    return SR_OK;
}


enum sr_return relay_read(void *relay)
{
    return _relay_read((serial_zmq_relay *)relay);
}


enum sr_return _relay_write(serial_zmq_relay *relay)
{
    enum sr_return flag;
    int bytes_writen;

    // Initialize ZMQ message
    zmq_msg_t msg;
    flag = check_zmq(zmq_msg_init(&msg));
    if (flag != SR_OK) return flag;

    // Check if a message is available to be received from socket
    flag = check_zmq(zmq_msg_recv(&msg, relay->serial_sub_socket, 0));

    // If we heard a message:
    if (flag == SR_OK)
    {
        // Check size of recieved message to make sure it can be copied into our buffer
        size_t msg_size = zmq_msg_size(&msg);
        if (msg_size > PORT_BUFFER_SIZE)
        {
            fprintf(stderr, "Message size is too large to write to serial port!");
            return SR_ERR_MEM;
        }

        // Copy the msg into the buffer and free ZMQ message
        memcpy(relay->msg_sub_buffer, zmq_msg_data(&msg), msg_size);
        flag = check_zmq(zmq_msg_close(&msg));
        if (flag != SR_OK) return flag;

        // Write message's bytes to ZMQ port
        bytes_writen = sp_blocking_write(relay->port,
                                         relay->msg_sub_buffer,
                                         msg_size,
                                         1000);
        flag = check_serial(bytes_writen);
        if (flag != SR_OK)
            return flag;

        debug_print("Wrote %d bytes: %.*s\n", bytes_writen, bytes_writen, relay->msg_sub_buffer);
    }

    return SR_OK;
}


enum sr_return relay_write(void *relay)
{
    return _relay_write((serial_zmq_relay *)relay);
}


enum sr_return _close_relay(serial_zmq_relay *relay)
{
    // Result check int
    enum sr_return flag;

    // Free the buffers
    free(relay->msg_pub_buffer);
    free(relay->msg_sub_buffer);

    // Close the zmq sockets and context
    flag = check_zmq(zmq_close(relay->serial_sub_socket));
    if (flag != SR_OK) return flag;

    flag = check_zmq(zmq_close(relay->serial_pub_socket));
    if (flag != SR_OK) return flag;

    flag = check_zmq(zmq_ctx_destroy(relay->context));
    if (flag != SR_OK) return flag;

    // Close out the serial port
    flag = check_serial(sp_close(relay->port));
    if (flag != SR_OK) return flag;

    sp_free_port(relay->port);

    return SR_OK;
}


enum sr_return close_relay(void *relay)
{
    return _close_relay((serial_zmq_relay *)relay);
}


void relay_launch(const char *port_name,
                  int baudrate,
                  const char *sub_endpoint,
                  const char *pub_endpoint)
{
    serial_zmq_relay *relay = open_relay(port_name, baudrate, sub_endpoint, pub_endpoint);
    if (relay == NULL)
    {
        fprintf(stderr, "Failed to initialize serial-zmq relay!");
        return;
    }
    else
    {
        while (true)
        {
            // Add checks here to make sure no errors were thrown
            relay_read(relay);
            relay_write(relay);
        }
        close_relay(relay);
        return;
    }
}


// Add a check valid serial_relay type ie not all nulls port is open etc.
enum sr_return check_zmq(int rc)
{
    if (rc == -1)
    {
        fprintf(stderr, "Error occurred during zmq_init(): %s\n", zmq_strerror(zmq_errno()));
        return SR_ERR_ZMQ;
    }
    else
    {
        return SR_OK;
    }
}


enum sr_return check_serial(enum sp_return ret_val)
{
    switch (ret_val)
    {
        case SP_ERR_ARG:
            fprintf(stderr, "Libserialport Error: Invalid argument.\n");
        case SP_ERR_FAIL:
            char *error_message = sp_last_error_message();
            fprintf(stderr, "Libserialport Error: Failed: %s\n", error_message);
            sp_free_error_message(error_message);
        case SP_ERR_SUPP:
            fprintf(stderr, "Libserialport Error: Not supported.\n");
        case SP_ERR_MEM:
            fprintf(stderr, "Libserialport Error: Couldn't allocate memory.\n");
        case SP_OK:
            return SR_OK;
        default:
            return SR_OK;
    }

    return SR_ERR_SP;
}
