#include <assert.h>
#include "serial_relay.h"

#define PORT_BUFFER_SIZE 1024

typedef struct _serial_zmq_relay
{
    // Setup port struct
    struct sp_port *port;

    // ZMQ socket
    void *context;
    // Socket which Mercury will message to (this is subscribing socket)
    void *serial_subscriber_socket;
    // Buffer used for recieving dumping serial port buffer into publisher
    uint8_t *msg_sub_buffer;
    // Socket which Mercury will listen to (this is publishing socket)
    void *serial_publisher_socket;
    // Buffer used for recieving dumping serial port buffer into publisher
    uint8_t *msg_pub_buffer;

    bool should_finish;

} serial_zmq_relay;


// Open a serial port in read write mode and the associated ZMQ ports.
// If any issue arises closes everything and returns a NULL pointer.
void *open_relay(const char *port_name,
                 int baudrate,
                 const char *sub_endpoint,
                 const char *pub_endpoint)
{
    // Allocate memory for relay object
    serial_zmq_relay *relay = calloc(1, sizeof(serial_zmq_relay));
    if (relay == NULL)
    {
        fprintf(stderr, "Failed to allocate serial_zmq_relay object!\n");
        goto fail_relay_calloc;
    }

    // Result check ints
    enum sp_return pc;
    int rc = 0;
    int conflate = 1;

    // ***************** Initialize Pointers *****************
    // Setup the serial ports
    pc = sp_get_port_by_name(port_name, &(relay->port));
    if (pc != SP_OK)
    {
        fprintf(stderr, "Failed to find serial port by name %s!\n", port_name);
        goto fail_port_name;
    }
    pc = sp_open(relay->port, SP_MODE_READ);
    if (pc != SP_OK)
    {
        fprintf(stderr, "Failed to open serial port %s!\n", port_name);
        goto fail_sp_open;
    }
    pc = sp_set_baudrate(relay->port, baudrate);
    if (pc != SP_OK)
    {
        fprintf(stderr, "Failed to set serial port baudrate to %d!\n", baudrate);
        goto fail_set_baudrate;
    }
    // // Record the size of the msg to be read from the buffer
    // relay->msg_size = msg_size;

    // Setup the message buffers
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
    relay->serial_publisher_socket = zmq_socket(relay->context, ZMQ_PUB);
    if (relay->serial_publisher_socket == NULL)
    {
        fprintf(stderr, "Failed to create ZMQ publisher socket!\n");
        goto fail_pub_socket;
    }
    relay->serial_subscriber_socket = zmq_socket(relay->context, ZMQ_SUB);
    if (relay->serial_subscriber_socket == NULL)
    {
        fprintf(stderr, "Failed to create ZMQ subscriber socket!\n");
        goto fail_sub_socket;
    }

    // Setup serial subscriber, also set conflate option
    rc = zmq_setsockopt(relay->serial_subscriber_socket, ZMQ_SUBSCRIBE, "", 0);
    if (rc != 0)
    {
        fprintf(stderr, "Failed to set socket to subscriber!\n", sub_endpoint);
        goto fail_sub_setsockopt;
    }
    rc = zmq_setsockopt(relay->serial_subscriber_socket, ZMQ_CONFLATE, &conflate, sizeof(conflate));
    if (rc != 0)
    {
        fprintf(stderr, "Failed to set subscriber conflate option!\n");
        goto fail_sub_setsockopt;
    }
    rc = zmq_connect(relay->serial_subscriber_socket, sub_endpoint);
    if (rc != 0)
    {
        fprintf(stderr, "Failed to connect ZMQ subscriber to port: %s!\n", sub_endpoint);
        goto fail_sub_connect;
    }

    // Set conflate option for serial publisher
    rc = zmq_setsockopt(relay->serial_publisher_socket, ZMQ_CONFLATE, &conflate, sizeof(conflate));
    if (rc != 0)
    {
        fprintf(stderr, "Failed to set publisher conflate option!\n");
        goto fail_pub_setsockopt;
    }
    rc = zmq_bind(relay->serial_publisher_socket, pub_endpoint);
    if (rc != 0)
    {
        fprintf(stderr, "Failed to bind ZMQ publisher to port %s\n", pub_endpoint);
        goto fail_pub_bind;
    }

    relay->should_finish = false;

    return relay;

fail_pub_bind:
fail_pub_setsockopt:
fail_sub_connect:
fail_sub_setsockopt:
    zmq_close(relay->serial_subscriber_socket);
fail_sub_socket:
    zmq_close(relay->serial_publisher_socket);
fail_pub_socket:
    zmq_ctx_destroy(relay->context);
fail_context:
    free(relay->msg_pub_buffer);
fail_pub_buffer:
    free(relay->msg_sub_buffer);
fail_sub_buffer:
fail_set_baudrate:
    sp_close(relay->port);
    sp_free_port(relay->port);
fail_sp_open:
fail_port_name:
    free(relay);
fail_relay_calloc:
    return NULL;
}

void _relay_read(serial_zmq_relay *relay)
{
    int pc = 0;
    int rc = 0;

    // Check how many bytes are avalible from the serial port and read them in
    int bytes_waiting = sp_input_waiting(relay->port);
    if (bytes_waiting > 0)
    {
        pc = sp_blocking_read(relay->port,
                              (void *)relay->msg_pub_buffer,
                              bytes_waiting,
                              (unsigned int)1000);
        assert(pc == bytes_waiting);

        // Relay those bytes through zmq
        rc = zmq_send(relay->serial_publisher_socket,
                      (void *)relay->msg_pub_buffer,
                      bytes_waiting,
                      0);
        assert(rc == bytes_waiting);
    }

    return;
}

void relay_read(void *relay)
{
    return _relay_read((serial_zmq_relay *)relay);
}

void _relay_write(serial_zmq_relay *relay)
{
    int pc = 0;

    // Read bytes from ZMQ message
    int nbytes = zmq_recv(relay->serial_subscriber_socket,
                          (void *)relay->msg_sub_buffer,
                          PORT_BUFFER_SIZE,
                          ZMQ_DONTWAIT);

    if (nbytes > 0)
    {
        pc = sp_nonblocking_write(relay->port,
                                  relay->msg_pub_buffer,
                                  nbytes);
        assert(pc == nbytes);
    }

    return;
}

void relay_write(void *relay)
{
    return _relay_write((serial_zmq_relay *)relay);
}

void _close_relay(serial_zmq_relay *relay)
{
    // Result check int
    enum sp_return pc;
    int rc = 0;

    // Free the buffers
    free(relay->msg_pub_buffer);
    free(relay->msg_sub_buffer);

    // Close the zmq sockets and context
    rc = zmq_close(relay->serial_subscriber_socket);
    assert(rc == 0);
    rc = zmq_close(relay->serial_publisher_socket);
    assert(rc == 0);
    rc = zmq_ctx_destroy(relay->context);
    assert(rc == 0);

    // Close out the serial port
    pc = sp_close(relay->port);
    assert(pc == SP_OK);
    sp_free_port(relay->port);

    return;
}

bool close_relay(void *relay)
{
    return _close_relay((serial_zmq_relay *)relay);
}

void _relay_launch(serial_zmq_relay *relay)
{
    while (!relay->should_finish)
    {
        relay_read(relay);
        relay_write(relay);
    }
    close_relay(relay);
}

void relay_launch(void *relay)
{
    return _relay_launch((serial_zmq_relay *)relay);
}

void _stop_relay(serial_zmq_relay *relay)
{
    relay->should_finish = true;
    return;
}

void stop_relay(void *relay)
{
    return _stop_relay((serial_zmq_relay *)relay);
}