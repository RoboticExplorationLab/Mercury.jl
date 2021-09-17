module Mercury

import ZMQ
import Sockets
import ProtoBuf
import Logging
import StaticArrays
import LibSerialPort

# Import correct library name for specific system
libhg_library_filename = ""
if Sys.islinux()
    libhg_library_filename = joinpath(@__DIR__, "..", "deps", "build", "libhg.so")
elseif Sys.isapple()
    libhg_library_filename = joinpath(@__DIR__, "..", "deps", "build", "libhg.dylib")
end
const libhg = libhg_library_filename


ZMQ_CONFLATE = 54

# Set conflate option for ZMQ, not included in ZMQ.jl
function set_conflate(socket::ZMQ.Socket, option_val::Integer)
    rc = ccall((:zmq_setsockopt, ZMQ.libzmq), Cint,
            (Ptr{Cvoid}, Cint, Ref{Cint}, Csize_t),
            socket, ZMQ_CONFLATE, option_val, sizeof(Cint))
    if rc != 0
        throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
    end
end

# # Get the conflate option for ZMQ, not included in ZMQ.jl
function get_conflate(socket::ZMQ.Socket, option_val::Integer)
    rc = ccall((:zmq_getsockopt, ZMQ.libzmq), Cint,
            (Ptr{Cvoid}, Cint, Ref{Cint}, Csize_t),
            socket, ZMQ_CONFLATE, option_val, sizeof(Cint))
    if rc != 0
        throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
    end
end

greet() = print("Hello World!")
include("utils.jl")

include("publishers/publishers.jl")
using .Publishers

include("subscribers/subscribers.jl")
using .Subscribers

end # module
