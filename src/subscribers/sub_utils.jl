
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
