#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include <libserialport.h>
#include <zmq.h>

/**
 * @brief Serial relay error flags.
 */
enum sr_return
{
    SR_OK = 0, /**< Operation completed successfully. */
    SR_ERR_SP = -1, /**< Operation failed due to a libserialport error. */
    SR_ERR_ZMQ = -2, /**< Operation failed due to a libzmq error. */
    SR_ERR_MEM = -3, /**< Operation failed due a serial relay memory allocation failure. */
};

/**
 * @brief Function to initialize a serial relay, ie. setup read/write port and
 * connect to zmq sockets for subscribing to and publishing data going to and
 * from the serial port.
 *
 * @param port_name File name of serial port device file (eg. `/dev/ttyACM0`)
 * @param baudrate Integer baudrate at which to communiacate with serial device
 * @param sub_endpoint String tcp address and port (eg. `tcp://127.0.0.1:5555`)
 * defining the zmq socket which subscribes to data that is relayed to the serial
 * device.
 * @param pub_endpoint String tcp address and port (eg. `tcp://127.0.0.1:5556`)
 * defining the zmq socket which publishes the data that is read from the serial
 * device.
 * @return void* Pointer to the opaque serial_relay object. If `NULL`, failed to
 * properly initialize the serial relay.
 */
void *open_relay(const char *port_name,
                 int baudrate,
                 const char *sub_endpoint,
                 const char *pub_endpoint);

/**
 * @brief Read bytes from serial device and relay as message over zmq publisher.
 *
 * @param relay Pointer to the opaque serial_relay object. Assumed non-NULL.
 * @return enum sr_return Flag describing error or successfull relay.
 */
enum sr_return relay_read(void *relay);

/**
 * @brief Read message from zmq subscriber socket and relay bytes over serial port.
 *
 * @param relay Pointer to the opaque serial_relay object. Assumed non-NULL.
 * @return enum sr_return Flag describing error or successfull relay.
 */
enum sr_return relay_write(void *relay);

/**
 * @brief Read msg from zmq subscriber socket and relay bytes over serial port.
 *
 * @param relay Pointer to the opaque serial_relay object. Assumed non-NULL.
 * @return enum sr_return Flag describing error or successfull relay.
 */
enum sr_return close_relay(void *relay);

/**
 * @brief Build and launch a serial relay which continually does two jobs
 * 1 - listens to a ZMQ subscriber and writes received messages to a serial device.
 * 2 - listens to a serial device and writes received bytes as ZMQ message over a
 * publisher.
 *
 * @param port_name File name of serial port device file (eg. `/dev/ttyACM0`)
 * @param baudrate Integer baudrate at which to communiacate with serial device
 * @param sub_endpoint String tcp address and port (eg. `tcp://127.0.0.1:5555`)
 * defining the zmq socket which subscribes to data that is relayed to the serial
 * device.
 * @param pub_endpoint String tcp address and port (eg. `tcp://127.0.0.1:5556`)
 * defining the zmq socket which publishes the data that is read from the serial
 * device.
 */
void relay_launch(const char *port_name,
                  int baudrate,
                  const char *sub_endpoint,
                  const char *pub_endpoint);