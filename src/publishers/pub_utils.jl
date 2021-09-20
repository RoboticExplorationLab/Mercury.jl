NUM_PUBS = 1;
function genpublishername()
    global NUM_PUBS
    name = "publisher_$NUM_PUBS"
    NUM_PUBS += 1
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

reset_pub_count() = global NUM_PUBS = 1

tcpstring(ipaddr, port) = "tcp://" * string(ipaddr) * ":" * string(port)
