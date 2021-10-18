#include <stdio.h>
#include <stdbool.h>

#include "serial_relay.h"

// const char *port_name = "/dev/tty.usbmodem92225501";
// int baudrate = 115200;
// const char *sub_endpoint = "tcp://127.0.0.1:5556";
// const char *pub_endpoint = "tcp://127.0.0.1:5557";

int main(int argc, char **argv)
{
    if (argc != 5)
    {
        fprintf(stderr, "Expects 4 additional command line arguments: (port_name, baudrate, sub_endpoint, pub_endpoint)", errno);
        return 0;
    }

    const char *port_name;
    int baudrate;
    const char *sub_endpoint;
    const char *pub_endpoint;

    port_name = argv[1];
    if (sscanf(argv[2], "%i", &baudrate) != 1)
    {
        fprintf(stderr, "error - not an integer");
    }
    sub_endpoint = argv[3];
    pub_endpoint = argv[4];

    relay_launch(port_name,
                 baudrate,
                 sub_endpoint,
                 pub_endpoint);

    return 1;
}
