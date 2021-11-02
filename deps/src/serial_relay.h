#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include <libserialport.h>
#include <zmq.h>

#define DEBUG 1

enum sr_return
{
    // Operation completed successfully
    SR_OK = 0,
    // libserialport error
    SR_ERR_SP = -1,
    // libzmq error
    SR_ERR_ZMQ = -2,
    // A memory allocation failure
    SR_ERR_MEM = -3,
};

// Open a serial port in read write mode and the associated ZMQ ports.
// If any issue arises closes everything and returns a NULL pointer.
void *open_relay(const char *port_name,
                 int baudrate,
                 const char *sub_endpoint,
                 const char *pub_endpoint);

enum sr_return relay_read(void *relay);
enum sr_return relay_write(void *relay);

enum sr_return close_relay(void *relay);

void relay_launch(const char *port_name,
                  int baudrate,
                  const char *sub_endpoint,
                  const char *pub_endpoint);