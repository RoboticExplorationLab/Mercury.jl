#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#include <libserialport.h>
#include <zmq.h>

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