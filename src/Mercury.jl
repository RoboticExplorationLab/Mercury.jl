module Mercury
import ZMQ
import Sockets
import ProtoBuf
import Logging

NUM_PUBS = 1;
function genpublishername()
    global NUM_PUBS
    name = "publisher_$NUM_PUBS"
    NUM_PUBS += 1
    return name
end
NUM_SUBS = 1;
function gensubscribername()
    global NUM_SUBS
    name = "subscriber_$NUM_SUBS"
    NUM_SUBS += 1
    return name
end
reset_pub_count() = global NUM_PUBS = 1
reset_sub_count() = global NUM_SUBS = 1

tcpstring(ipaddr, port) = "tcp://" * string(ipaddr) * ":" * string(port)

greet() = print("Hello World!")
include("publisher.jl")

end # module
