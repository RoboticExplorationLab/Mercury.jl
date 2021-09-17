"""
    ZmqSubscriber

A simple wrapper around a ZMQ subscriber, but only for protobuf messages.

# Construction

    Subscriber(context::ZMQ.Context, ipaddr, port; name)

To create a subscriber, pass in a `ZMQ.Context`, which allows all related
publisher / subscribers to be collected in a "group." The subscriber also
needs to be provided the IPv4 address (either as a string or as a `Sockets.IPv4`
object), and the port (either as an integer or a string).

A name can also be optionally provided via the `name` keyword, which can be used
to provide a helpful description about what the subscriber is subscribing to. It defaults
to "subscriber_#" where `#` is an increasing index.

# Usage
Use the blocking `subscribe` method to continually listen to the socket and
store data in a protobuf type:

    subscribe(sub::Subscriber, proto_msg::ProtoBuf.ProtoType)

Note that this function contains an infinite while loop so will block the calling
thread indefinately. It's usually best to assign the process to a separate thread / task:

```
sub_task = @task subscribe(sub, proto_msg)
schedule(sub_task)
```
"""
struct ZmqSubscriber <: Subscriber
    socket::ZMQ.Socket
    port::Int64
    ipaddr::Sockets.IPv4
    buffer::IOBuffer
    name::String
    function ZmqSubscriber(
        ctx::ZMQ.Context,
        ipaddr::Sockets.IPv4,
        port::Integer;
        name = gensubscribername(),
    )
        local socket
        @catchzmq(
            socket = ZMQ.Socket(ctx, ZMQ.SUB),
            "Could nnot create socket for subscriber $name."
        )
        @catchzmq(
            ZMQ.subscribe(socket),
            "Could not set the socket as a subscriber for subscriber $name."
        )
        @catchzmq(
            set_conflate(socket, 1),
            "Could not set the conflate option for subscriber $name."
        )
        @catchzmq(
            ZMQ.connect(socket, "tcp://$ipaddr:$port"),
            "Could not connect subscriber $name to port $(tcpstring(ipaddr, port))."
        )

        @info "Subscribing $name to: tcp://$ipaddr:$port"
        new(socket, port, ipaddr, IOBuffer(), name)
    end
end
function ZmqSubscriber(ctx::ZMQ.Context, ipaddr, port::Integer; name = gensubscribername())
    if !(ipaddr isa Sockets.IPv4)
        ipaddr = Sockets.IPv4(ipaddr)
    end
    ZmqSubscriber(ctx, ipaddr, port, name = name)
end
function ZmqSubscriber(
    ctx::ZMQ.Context,
    ipaddr,
    port::AbstractString;
    name = gensubscribername(),
)
    ZmqSubscriber(ctx, ipaddr, parse(Int, port), name = name)
end
function ZmqSubscriber(sub::ZmqSubscriber)
    return sub
end
Base.isopen(sub::ZmqSubscriber) = Base.isopen(sub.socket)
Base.close(sub::ZmqSubscriber) = Base.close(sub.socket)

function receive(
    sub::ZmqSubscriber,
    proto_msg::ProtoBuf.ProtoType,
    write_lock = ReentrantLock(),
)
    if isopen(sub)
        bin_data = ZMQ.recv(sub.socket)

        # Forces subscriber to conflate messages
        # #define ZMQ_POLLIN 1
        # int event = ZMQ_POLLIN;
        # zmq_getsockopt(sub, ZMQ_EVENTS, &event, &event_size);
        ZMQ.get_events(sub.socket)

        io = seek(convert(IOStream, bin_data), 0)
        lock(write_lock) do
            ProtoBuf.readproto(io, proto_msg)
        end
    else
        @warn "Attempting to receive a message on subscriber $(sub.name), which is closed"
    end
end

function subscribe(
    sub::ZmqSubscriber,
    proto_msg::ProtoBuf.ProtoType,
    write_lock = ReentrantLock(),
)
    @info "Listening for message type: $(typeof(proto_msg)), on: tcp://$(string(sub.ipaddr)):$(sub.port)"
    try
        while true
            bin_data = ZMQ.recv(sub)
            # lock
            # Why not just call IOBuffer(bin_data)?
            io = seek(convert(IOStream, bin_data), 0)
            lock(write_lock) do
                readproto(io, proto_msg)
            end
            # unlock

            GC.gc(false)
        end
    catch e
        close(ctx)
        close(sub)
        @info "Shutting Down $(typeof(proto_msg)) subscriber, on: tcp://$sub_ip:$sub_port"

        rethrow(e)
    end

    return nothing
end

tcpstring(sub::ZmqSubscriber) = "tcp://" * string(sub.ipaddr) * ":" * string(sub.port)