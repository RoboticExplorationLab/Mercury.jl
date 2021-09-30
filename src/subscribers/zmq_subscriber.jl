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
    socket_lock::ReentrantLock
    flags::SubscriberFlags
    should_finish::Threads.Atomic{Bool}

    function ZmqSubscriber(
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
        @show isopen(socket)
        should_finish = Threads.Atomic{Bool}(false)
        new(
            socket,
            port,
            ipaddr,
            IOBuffer(),
            name,
            ReentrantLock(),
            SubscriberFlags(),
            should_finish,
        )
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

function Subscriber(sub::ZmqSubscriber)
    return sub
end

Base.isopen(sub::ZmqSubscriber) = isopen(sub.socket)

function Base.close(sub::ZmqSubscriber, timeout = 1)
    lock(sub.socket_lock) do
        @info "Closing ZmqSubscriber: $(getname(sub))"
        close(sub.socket)
    end
end

function forceclose(sub::ZmqSubscriber)
    @warn "Force closing ZmqSubscriber: $(getname(sub))"
    close(sub.socket)
end

function receive(sub::ZmqSubscriber, buf, write_lock::ReentrantLock = ReentrantLock())
    did_receive = false
    sub.flags.isreceiving = true
    local bin_data
    lock(sub.socket_lock) do
        if isopen(sub)  # must take lock before checking if the socket is open
            # bin_data = ZMQ.Message()
            # bytes_read = ZMQ.msg_recv(sub.socket, bin_data, ZMQ.ZMQ_DONTWAIT)
            bin_data = ZMQ.recv(sub.socket)

            # Once blocking is finished we know we've recieved a new message
            sub.flags.hasreceived = true
            did_receive = true

            # Forces subscriber to conflate messages
            ZMQ.getproperty(sub.socket, :events)
        end
    end
    sub.flags.isreceiving = false

    # Why not just call IOBuffer(bin_data)?
    # io = seek(convert(IOStream, bin_data), 0)
    if did_receive
        lock(write_lock) do
            decode!(buf, bin_data)
            # ProtoBuf.readproto(io, proto_msg)
        end
    end
end

function subscribe(sub::ZmqSubscriber, buf, write_lock::ReentrantLock)
    @info "$(sub.name): Listening for message type: $(typeof(buf)), on: $(tcpstring(sub))"

    try
        while isopen(sub)
            receive(sub, buf, write_lock)
            GC.gc(false)
            yield()
            if sub.should_finish[]
                break
            end
        end
        close(sub)
        @warn "Shutting Down subscriber $(getname(sub)) on: $(tcpstring(sub)). Socket was closed."
    catch err
        sub.flags.diderror = true
        close(sub)
        @show typeof(err)
        if !(err isa EOFError)  # catch the EOFError throw when force closing the socket
            @warn "Shutting Down subscriber $(getname(sub)) on: $(tcpstring(sub)). Socket errored out."
            rethrow(err)
        else
            @warn "Shutting Down subscriber $(getname(sub)) on: $(tcpstring(sub)). Socket was forcefully closed."
        end
    end

    return nothing
end

tcpstring(sub::ZmqSubscriber) = tcpstring(sub.ipaddr, sub.port)

"""
    publish_until_receive(pub, sub, msg_out; [timeout])

Publish a message via the publisher `pub` until it's received by the subscriber `sub`.
Both `pub` and `sub` should have the same port and IP address.

The function returns `true` if a message was received before `timeout` seconds have passed,
    and `false` otherwise.
"""
function publish_until_receive(
    pub::ZmqPublisher,
    sub::ZmqSubscriber,
    msg_out::ProtoBuf.ProtoType,
    timeout = 1.0,  # seconds
)
    @assert pub.ipaddr == sub.ipaddr && pub.port == sub.port "Publisher and subscriber must be on the same port!"
    @assert isopen(pub) "Publisher must be open"
    @assert isopen(sub) "Subscriber must be open"
    t_start = time()
    sub.flags.hasreceived = false
    while (time() - t_start < timeout)
        publish(pub, msg_out)
        sleep(0.001)
        if sub.flags.hasreceived
            return true
        end
    end
    @warn "Publish until receive timed out"
    return false
end
