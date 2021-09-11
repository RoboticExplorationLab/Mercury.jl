"""
    SubscriberFlags

Some useful flags when dealing with subscribers. Describes the state of the system.
Particularly helpful when the subscriber is actively receiving messages in another
thread and you want to query the state of the subscriber.
"""
Base.@kwdef mutable struct SubscriberFlags
    "Is the subscriber currently waiting to receive data"
    isreceiving::Bool = false

    "Did the subscriber exit with an error"
    diderror::Bool = false

    "Has the subscriber received a message"
    hasreceived::Bool = false
end


"""
    Subscriber

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
struct Subscriber
    socket::ZMQ.Socket
    port::Int64
    ipaddr::Sockets.IPv4
    buffer::IOBuffer
    name::String
    socket_lock::ReentrantLock
    flags::SubscriberFlags
    rate_info::RateInfo
    function Subscriber(
        ctx::ZMQ.Context,
        ipaddr::Sockets.IPv4,
        port::Integer;
        name = gensubscribername(),
    )
        local socket
        @catchzmq(
            socket = ZMQ.Socket(ctx, ZMQ.SUB),
            "Could not create socket for subscriber $name."
        )
        # @catchzmq(
        #     ZMQ._set_rcvhwm(socket, 1),
        #     "Could not set high water mark for subscriber $name."
        # )

        # @catchzmq(
        #     set_conflate(socket, 1),
        #     "Could not set the conflate option for subscriber $name."
        # )
        # println("Set conflate option to true")

        @catchzmq(
            ZMQ.subscribe(socket),
            "Could not set the socket as a subscriber for subscriber $name."
        )


        @catchzmq(
            ZMQ.connect(socket, "tcp://$ipaddr:$port"),
            "Could not connect subscriber $name to port $(tcpstring(ipaddr, port))."
        )

        @info "Subscribing $name to: tcp://$ipaddr:$port"
        new(
            socket,
            port,
            ipaddr,
            IOBuffer(),
            name,
            ReentrantLock(),
            SubscriberFlags(),
            RateInfo(),
        )
    end
end

function Subscriber(ctx::ZMQ.Context, ipaddr, port::Integer; name = gensubscribername())
    if !(ipaddr isa Sockets.IPv4)
        ipaddr = Sockets.IPv4(ipaddr)
    end
    Subscriber(ctx, ipaddr, port, name = name)
end

function Subscriber(
    ctx::ZMQ.Context,
    ipaddr,
    port::AbstractString;
    name = gensubscribername(),
)
    Subscriber(ctx, ipaddr, parse(Int, port), name = name)
end

function Subscriber(sub::Subscriber)
    return sub
end

Base.isopen(sub::Subscriber) = Base.isopen(sub.socket)
function Base.close(sub::Subscriber)
    lock(sub.socket_lock) do
        Base.close(sub.socket)
    end
end
forceclose(sub::Subscriber) = Base.close(sub.socket)
getname(sub::Subscriber) = sub.name

function receive(
    sub::Subscriber,
    proto_msg::ProtoBuf.ProtoType,
    write_lock = ReentrantLock(),
)
    if isopen(sub)
        sub.flags.isreceiving = true
        # local bin_data
        bin_data = ZMQ.Message()
        lock(sub.socket_lock) do
            # ZMQ.msg_recv(sub.socket, bin_data, ZMQ.ZMQ_DONTWAIT)
            bin_data = ZMQ.recv(sub.socket)
        end
        sub.flags.isreceiving = false
        sub.flags.hasreceived = true
        # Why not just call IOBuffer(bin_data)?
        io = seek(convert(IOStream, bin_data), 0)
        lock(write_lock) do
            ProtoBuf.readproto(io, proto_msg)
        end

        printrate(sub.rate_info)
    end
end

function subscribe(
    sub::Subscriber,
    proto_msg::ProtoBuf.ProtoType,
    write_lock = ReentrantLock(),
)
    @info "Listening for message type: $(typeof(proto_msg)), on: $(tcpstring(sub))"
    init(sub.rate_info, getname(sub))
    try
        while isopen(sub)
            receive(sub, proto_msg, write_lock)
            GC.gc(false)  # TODO(bjack205)[#8] Is this needed?
            # sleep(0.001)
            yield()
        end
        @warn "Shutting Down subscriber $(getname(sub)) on: $(tcpstring(sub)). Socket was closed."
    catch e
        close(sub)
        @warn "Shutting Down subscriber $(getname(sub)) on: $(tcpstring(sub)). Got error $(typeof(e))."
        sub.flags.diderror = true
        rethrow(e)
    end

    return nothing
end

"""
    publish_until_receive(pub, sub, msg_out; [timeout])

Publish a message via the publisher `pub` until it's received by the subscriber `sub`.
Both `pub` and `sub` should have the same port and IP address. 

The function returns `true` if a message was received before `timeout` seconds have passed,
    and `false` otherwise.
"""
function publish_until_receive(
    pub::Publisher,
    sub::Subscriber,
    msg_out::ProtoBuf.ProtoType,
    timeout = 1.0,  # seconds
)
    @assert pub.ipaddr == sub.ipaddr && pub.port == sub.port "Publisher and subscriber must be on the same port!"
    t_start = time()
    sub.flags.hasreceived = false
    while (time() - t_start < timeout)
        publish(pub, msg_out)
        sleep(0.001)
        if sub.flags.hasreceived
            return true
        end
    end
    return false
end

tcpstring(sub::Subscriber) = tcpstring(sub.ipaddr, sub.port)
