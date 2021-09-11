module Mercury
import ZMQ
import Sockets
import ProtoBuf
import Logging

const libhg = joinpath(@__DIR__, "..", "deps", "build", "libhg.so")

function set_conflate(socket::ZMQ.Socket, option_val::Integer)
    rc = ccall((:zmq_getsockopt, ZMQ.libzmq), Cint,
            (Ptr{Cvoid}, Cint, Ref{Cint}, Ref{Csize_t}),
            socket, 54, option_val, sizeof(Cint))
    if rc != 0
        throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
    end
end

greet() = print("Hello World!")
include("utils.jl")
include("rate_info.jl")
include("publisher.jl")
include("subscriber.jl")
include("node.jl")

end # module
