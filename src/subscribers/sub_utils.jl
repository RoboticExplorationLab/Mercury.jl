ZMQ_CONFLATE = 54

# Set conflate option for ZMQ, not included in ZMQ.jl
function set_conflate(socket::ZMQ.Socket, option_val::Integer)
    rc = ccall(
        (:zmq_setsockopt, ZMQ.libzmq),
        Cint,
        (Ptr{Cvoid}, Cint, Ref{Cint}, Csize_t),
        socket,
        ZMQ_CONFLATE,
        option_val,
        sizeof(Cint),
    )
    if rc != 0
        throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
    end
end
# Get the conflate option for ZMQ, not included in ZMQ.jl
function get_conflate(socket::ZMQ.Socket, option_val::Integer)
    rc = ccall(
        (:zmq_getsockopt, ZMQ.libzmq),
        Cint,
        (Ptr{Cvoid}, Cint, Ref{Cint}, Csize_t),
        socket,
        ZMQ_CONFLATE,
        option_val,
        sizeof(Cint),
    )
    if rc != 0
        throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
    end
end

NUM_SUBS = 1;
function gensubscribername()
    global NUM_SUBS
    name = "subscriber_$NUM_SUBS"
    NUM_SUBS += 1
    return name
end

macro catchzmq(expr, errmsg)
    ex = quote
        try
            $expr
        catch e
            if e isa ZMQ.StateError
                @error $errmsg * "\n" * ZMQ.jl_zmq_error_str()
            end
            rethrow(e)
        end
    end
    return esc(ex)
end

macro catchserial(expr, errmsg)
    ex = quote
        try
            $expr
        catch e
            if e isa ErrorException
                @error $errmsg * "\n"
            end
            rethrow(e)
        end
    end
    return esc(ex)
end

reset_sub_count() = global NUM_SUBS = 1

tcpstring(ipaddr, port) = "tcp://" * string(ipaddr) * ":" * string(port)
