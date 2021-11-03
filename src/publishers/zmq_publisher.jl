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
    socket_lock::ReentrantLock
    flags::PublisherFlags

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
            IOBuffer(zeros(UInt8, buffersize); read = true, write = true),
            name,
            ReentrantLock(),
            PublisherFlags(),
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
    lock(pub.socket_lock) do
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

function publish(pub::ZmqPublisher, msg::MercuryMessage)
    pub.flags.has_published = false

    bytes_sent = Int32(0)
    if isopen(pub)
        # Encode the message with protobuf
        msg_size = encode!(msg, pub.buffer)
        getflags(pub).bytespublished = msg_size

        # Create a new message to be sent and copy the encoded protobuf bytes
        zmsg = ZMQ.Message(msg_size)
        copyto!(zmsg, 1, pub.buffer.data, 1, msg_size)

        # Send over ZMQ
        # NOTE: ZMQ will de-allocate the message allocated above, so garbage
        # collection should not be an issue here
        ZMQ.send(pub.socket, zmsg)
        getflags(pub).has_published = true

        # Move to the beginning of the buffer
        seek(pub.buffer, 0)
    end
end

portstring(pub::ZmqPublisher) = tcpstring(pub.ipaddr, pub.port)
