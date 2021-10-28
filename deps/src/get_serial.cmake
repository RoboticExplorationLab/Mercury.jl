cmake_minimum_required(VERSION 3.0.0)

########################################
# Download libserialports dependencies
########################################
include(ExternalProject)  # pull in the `ExternalProject` CMake module

get_filename_component(SERIALPORT_PRE ${CMAKE_CURRENT_BINARY_DIR}/_deps/libserialport ABSOLUTE)
get_filename_component(SERIALPORT_DIR ${SERIALPORT_PRE}/libserialport-src ABSOLUTE)

ExternalProject_Add(serialport
    PREFIX "${SERIALPORT_PRE}"
    GIT_REPOSITORY "https://github.com/sigrokproject/libserialport"

    BUILD_IN_SOURCE true
    SOURCE_DIR "${SERIALPORT_DIR}"

    CONFIGURE_COMMAND ${SERIALPORT_DIR}/autogen.sh && ${SERIALPORT_DIR}/configure
    BUILD_COMMAND make
    INSTALL_COMMAND "" # Dont want sys wide install
    UPDATE_COMMAND "" # don't rebuild every time
)

get_filename_component(SERIALPORT_LIB_DIR ${SERIALPORT_DIR}/.libs ABSOLUTE)

add_library(libserialport SHARED IMPORTED GLOBAL)
add_dependencies(libserialport serialport)

if (APPLE)
    set(SERIALPORT_LIB "${SERIALPORT_LIB_DIR}/libserialport.dylib")
elseif (LINUX)
    set(SERIALPORT_LIB "${SERIALPORT_LIB_DIR}/libserialport.so")
endif()

message(STATUS "library found at ${SERIALPORT_LIB}")
set_target_properties(libserialport PROPERTIES
    IMPORTED_LOCATION ${SERIALPORT_LIB}
)
