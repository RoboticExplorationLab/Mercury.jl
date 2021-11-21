cmake_minimum_required(VERSION 3.0.0)
project(Mercury VERSION 0.1 LANGUAGES C)

include(get_serial.cmake)
include(get_zmq.cmake)

# Build the serial relay exectuble
add_executable(relay_launch
    serial_relay.h
    crc8.h
    serial_relay.c
    crc8.c
    relay_launch.c
)
target_compile_definitions(relay_launch
    PRIVATE
    DEBUG=0
)
target_link_libraries(relay_launch
    PRIVATE
        libserialport
        libzmq
)


# build the Mercury library
add_library(hg
    SHARED
    mercury.h
    mercury.c
)
# Link against zmq and libserialport (prefer private over public linking)
target_link_libraries(hg
    PRIVATE
    libzmq
)