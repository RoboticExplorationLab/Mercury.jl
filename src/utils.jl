ZMQ_CONFLATE = 54

struct MercuryException <: Exception
    msg::String
end
Base.showerror(io::IO, e::MercuryException) = print(io, "Error from Mercury: " * e.msg)

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

NUM_PUBS = 1;
reset_pub_count() = global NUM_PUBS = 1
function genpublishername()
    global NUM_PUBS
    name = "publisher_$NUM_PUBS"
    NUM_PUBS += 1
    return name
end

NUM_SUBS = 1;
reset_sub_count() = global NUM_SUBS = 1
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
            if e isa LibSerialPort.Timeout
                @error "LibSerialPort Timeout error thrown. Is a device connected to the serial port?\n"
            elseif e isa ErrorException
                @error $errmsg * "\n"
            end
            rethrow(e)
        end
    end
    return esc(ex)
end

tcpstring(ipaddr, port) = "tcp://" * string(ipaddr) * ":" * string(port)
