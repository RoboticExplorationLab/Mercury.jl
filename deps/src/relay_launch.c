#include <stdio.h>
#include <stdbool.h>

#include "serial_relay.h"


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
        fprintf(stderr, "Command line argument \"baudrate\" is not an integer!");
        return 1;
    }
    sub_endpoint = argv[3];
    pub_endpoint = argv[4];

    relay_launch(port_name,
                 baudrate,
                 sub_endpoint,
                 pub_endpoint);

    return 0;
}
