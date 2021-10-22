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
    zmsg::ZMQ.Message

    function ZmqSubscriber(
        ctx::ZMQ.Context,
        ipaddr::Sockets.IPv4,
        port::Integer;
        name = gensubscribername(),
        buffersize = 255,
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
        new(
            socket,
            port,
            ipaddr,
            IOBuffer(zeros(UInt8, buffersize)),
            name,
            ReentrantLock(),
            SubscriberFlags(),
            ZMQ.Message(),
        )
    end
end

function ZmqSubscriber(ctx::ZMQ.Context, ipaddr, port::Integer; kwargs...)
    if !(ipaddr isa Sockets.IPv4)
        ipaddr = Sockets.IPv4(ipaddr)
    end
    ZmqSubscriber(ctx, ipaddr, port; kwargs...)
end

function ZmqSubscriber(ctx::ZMQ.Context, ipaddr, port::AbstractString; kwargs...)
    ZmqSubscriber(ctx, ipaddr, parse(Int, port); kwargs...)
end

getcomtype(::ZmqSubscriber) = :zmq
function Base.isopen(sub::ZmqSubscriber)
    return lock(() -> ZMQ.isopen(sub.socket), sub.socket_lock)
end

function Base.close(sub::ZmqSubscriber)
    lock(sub.socket_lock) do
        if isopen(sub.socket)
            @debug "Closing ZmqSubscriber: $(getname(sub))"
            ZMQ.close(sub.socket)
        end
    end
end

function forceclose(sub::ZmqSubscriber)
    @warn "Force closing ZmqSubscriber: $(getname(sub))"
    close(sub.socket)
end

function receive(sub::ZmqSubscriber, msg::MercuryMessage)
    did_receive = false
    getflags(sub).isreceiving = true
    bin_data = sub.zmsg

    bytes_read = Int32(0)
    if isopen(sub)
        bytes_read = ZMQ.msg_recv(sub.socket, bin_data, ZMQ.ZMQ_DONTWAIT)::Int32
        getflags(sub).bytesrecieved = bytes_read

        if bytes_read == -1
            ZMQ.zmq_errno() == ZMQ.EAGAIN || throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
        else
            getflags(sub).hasreceived = true
            did_receive = true
        end

        # Forces subscriber to conflate messages
        ZMQ.getproperty(sub.socket, :events)
    end

    # TODO: test this code to make sure it works in practice
    if bytes_read > length(sub.buffer.data)
        @warn "Increasing buffer size for subscriber $(getname(sub)) from $(length(sub.buffer.data)) to $bytes_read."
        sub.buffer.data = zeros(UInt8, bytes_read)
        sub.buffer.size = bytes_read
    end

    # Copy the data to the local buffer and decode

    if did_receive
        seek(sub.buffer, 0)
        copyto!(pub.buffer.data, 1, bin_data, 1, bytes_read)
        sub.buffer.size = bytes_read

        decode!(msg, sub.buffer)
    end

    return did_receive
end

portstring(sub::ZmqSubscriber) = tcpstring(sub.ipaddr, sub.port)

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
    msg_out::MercuryMessage,
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
