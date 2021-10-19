#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include <libserialport.h>
#include <zmq.h>

void *open_relay(const char *port_name,
                 int baudrate,
                 //  size_t msg_size,
                 const char *sub_endpoint,
                 const char *pub_endpoint);

void relay_read(void *relay);
void relay_write(void *relay);

bool close_relay(void *relay);

bool relay_launch(const char *port_name,
                  int baudrate,
                  //   size_t msg_size,
                  const char *sub_endpoint,
                  const char *pub_endpoint);