using ZMQ

ctx = ZMQ.Context(1)
sock = ZMQ.Socket(ctx, ZMQ.PUB)
try
    ZMQ.bind(sock, "tcp://127.0.0.1:5555")
catch e
    if e isa ZMQ.StateError
        @show ZMQ.zmq_errno()
        @show ZMQ.jl_zmq_error_str()
    end
end

@which ZMQ.bind(sock, "tcp://127.0.0.1:5555")

isopen(sock)
close(sock)
