########################################
# Download libzmq dependencies
########################################
include(FetchContent)  # pull in the `FetchContent` CMake module

# Download libzmq into `build/_deps
FetchContent_Declare(libzmq
    GIT_REPOSITORY https://github.com/zeromq/libzmq
    GIT_TAG 4097855ddaaa65ed7b5e8cb86d143842a594eebd # version 4.3.4
)

# Include the libzmq CMake files in the current project (adds all of it's targets)
if(NOT libzmq_POPULATED)
    FetchContent_Populate(libzmq)
    set(ZMQ_BUILD_TESTS OFF CACHE BOOL "Test suite for libzmq")
    # To enable building on macOS, see github issue https://github.com/zeromq/libzmq/issues/4085
    set(WITH_TLS OFF CACHE INTERNAL "Disable TLS support")
    add_subdirectory(${libzmq_SOURCE_DIR} ${libzmq_BINARY_DIR})
endif()

# Modify the `libzmq` target generated by it's build system to include the zmq header
# files as part of its public interface
target_include_directories(libzmq
  PUBLIC
  $<BUILD_INTERFACE:${libzmq_SOURCE_DIR}/include>
)

