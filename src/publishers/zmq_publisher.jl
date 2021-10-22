"""
    Publisher

A simple wrapper around a ZMQ publisher, but only publishes protobuf messages.

# Construction

    Publisher(context::ZMQ.Context, ipaddr, port; name)

To create a publisher, pass in a `ZMQ.Context`, which allows all related
publisher / subscribers to be collected in a "group." The publisher also
needs to be provided the IPv4 address (either as a string or as a `Sockets.IPv4`
object), and the port (either as an integer or a string).

A name can also be optionally provided via the `name` keyword, which can be used
to provide a helpful description about what the publisher is publishing. It defaults
to "publisher_#" where `#` is an increasing index.

If the port

# Usage
To publish a message, just use the `publish` method on a protobuf type:

    publish(pub::Publisher, proto_msg::ProtoBuf.ProtoType)
"""
struct ZmqPublisher <: Publisher
    socket::ZMQ.Socket
    port::Int64
    ipaddr::Sockets.IPv4
    buffer::IOBuffer
    name::String
    flags::PublisherFlags
    socket_lock::ReentrantLock
    zmsg::ZMQ.Message

    function ZmqPublisher(
        ctx::ZMQ.Context,
        ipaddr::Sockets.IPv4,
        port::Integer;
        name = genpublishername(),
        buffersize = 255,
    )
        local socket
        @catchzmq(
            socket = ZMQ.Socket(ctx, ZMQ.PUB),
            "Could not create socket for publisher $name."
        )
        @catchzmq(
            ZMQ.bind(socket, "tcp://$ipaddr:$port"),
            "Could not bind publisher $name to $(tcpstring(ipaddr, port))"
        )

        @info "Publishing $name on: $(tcpstring(ipaddr, port)), isopen = $(isopen(socket))"
        new(
            socket,
            port,
            ipaddr,
            IOBuffer(zeros(UInt8, buffersize)),
            name,
            ReentrantLock(),
            PublisherFlags(),
            ZMQ.Message(),
            )
    end
end

function ZmqPublisher(ctx::ZMQ.Context, ipaddr, port::Integer; kwargs...)
    if !(ipaddr isa Sockets.IPv4)
        ipaddr = Sockets.IPv4(ipaddr)
    end
    ZmqPublisher(ctx, ipaddr, port; kwargs...)
end

function ZmqPublisher(ctx::ZMQ.Context, ipaddr, port::AbstractString; kwargs...)
    ZmqPublisher(ctx, ipaddr, parse(Int, port); kwargs...)
end

getcomtype(::ZmqPublisher) = :zmq
function Base.isopen(pub::ZmqPublisher)
    return lock(() -> ZMQ.isopen(pub.socket), pub.socket_lock)
end

function Base.close(pub::ZmqPublisher)
    lock(sub.socket_lock) do
        if isopen(pub.socket)
            @debug "Closing ZmqPublisher: $(getname(pub))"
            ZMQ.close(pub.socket)
        end
    end
end

function forceclose(pub::ZmqPublisher)
    @warn "Force closing ZmqPublisher: $(getname(pub))"
    close(pub.socket)
end

function publish(pub::ZmqPublisher, proto_msg::ProtoBuf.ProtoType)
    pub.flags.has_published = false

    bytes_sent = Int32(0)
    if isopen(pub)
        # Encode the message with protobuf
        msg_size = ProtoBuf.writeproto(pub.buffer, proto_msg)
        getflags(pub).bytespublished = msg_size

        # Create a new message to be sent and copy the encoded protobuf bytes
        msg = ZMQ.Message(msg_size)
        copyto!(msg, 1, pub.buffer.data, 1, msg_size)

        # Send over ZMQ
        # NOTE: ZMQ will de-allocate the message allocated above, so garbage
        # collection should not be an issue here
        ZMQ.send(pub.socket, msg)
        getflags(pub).has_published = true

        # Move to the beginning of the buffer
        seek(pub.buffer, 0)
    end
end

function publish(pub::ZmqPublisher, proto_msg::MercuryMessage)
    getflags(pub).has_published = false
    did_publish = false

    if isopen(pub)
        # Encode the message with protobuf
        msg_size = ProtoBuf.writeproto(pub.buffer, proto_msg)

        # Create a new message to be sent and copy the encoded protobuf bytes
        msg = ZMQ.Message(msg_size)
        seek(pub.buffer, 0)
        copyto!(msg, 1, pub.buffer.data, 1, msg_size)
        pub.buffer.size = bytes_read

        # Send over ZMQ
        # NOTE: ZMQ will de-allocate the message allocated above, so garbage
        # collection should not be an issue here
        ZMQ.send(pub.socket, msg)
        getflags(pub).has_published = true
        did_publish = true
    end

    return did_publish
end

portstring(pub::ZmqPublisher) = tcpstring(pub.ipaddr, pub.port)
