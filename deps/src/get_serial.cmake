cmake_minimum_required(VERSION 3.0.0)

########################################
# Download libserialports dependencies
########################################
include(ExternalProject)  # pull in the `ExternalProject` CMake module
include(CMakePrintHelpers)

# get_filename_component(SERIALPORT_PRE ${CMAKE_CURRENT_BINARY_DIR}/_deps/libserialport ABSOLUTE)
# get_filename_component(SERIALPORT_DIR ${SERIALPORT_PRE}/libserialport-src ABSOLUTE)

set(SERIALPORT_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/_deps/libserialport)
set(SERIALPORT_DIR ${SERIALPORT_PREFIX}/src/serialport)

# get_filename_component(SERIALPORT_PREFIX ${CMAKE_CURRENT_BINARY_DIR}/_deps/libserialport ABSOLUTE)
# get_filename_component(SERIALPORT_DIR ${SERIALPORT_PREFIX}/src/serialport ABSOLUTE)


ExternalProject_Add(serialport
    PREFIX "${SERIALPORT_PREFIX}"
    GIT_REPOSITORY "https://github.com/sigrokproject/libserialport"

    # BUILD_IN_SOURCE true
    # SOURCE_DIR "${SERIALPORT_DIR}"

    CONFIGURE_COMMAND ${SERIALPORT_DIR}/autogen.sh && ${SERIALPORT_DIR}/configure
    BUILD_COMMAND make
    INSTALL_COMMAND "" # Dont want sys wide install
    UPDATE_COMMAND "" # don't rebuild every time
)

# Set location of downloaded serialport libary
if (APPLE)
    set(SERIALPORT_LIB "${SERIALPORT_PREFIX}/src/serialport-build/.libs/libserialport.dylib")
elseif (UNIX)
    set(SERIALPORT_LIB "${SERIALPORT_PREFIX}/src/serialport-build/.libs/libserialport.so")
endif()

# Make library and make sure that serialport is built before including directories
# and seting properites
add_library(libserialport SHARED IMPORTED GLOBAL)
add_dependencies(libserialport serialport)
target_include_directories(libserialport
    INTERFACE ${SERIALPORT_DIR}
)
set_target_properties(libserialport PROPERTIES
    IMPORTED_LOCATION ${SERIALPORT_LIB}
)
