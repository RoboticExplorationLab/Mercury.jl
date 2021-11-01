#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include <libserialport.h>
#include <zmq.h>

#define DEBUG 1

enum sr_return
{
    /** Operation completed successfully. */
    SR_OK = 0,
    /** Invalid arguments were passed to the function. */
    SR_ERR_SP = -1,
    /** A system error occurred while executing the operation. */
    SR_ERR_ZMQ = -2,
    /** A memory allocation failed while executing the operation. */
    SR_ERR_MEM = -3,
};

void *open_relay(const char *port_name,
                 int baudrate,
                 const char *sub_endpoint,
                 const char *pub_endpoint);

void relay_read(void *relay);
void relay_write(void *relay);

void close_relay(void *relay);

void relay_launch(const char *port_name,
                  int baudrate,
                  const char *sub_endpoint,
                  const char *pub_endpoint);