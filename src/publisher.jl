
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
struct Publisher
    socket::ZMQ.Socket
    port::Int64
    ipaddr::Sockets.IPv4
    buffer::IOBuffer
    name::String
    function Publisher(
        ctx::ZMQ.Context,
        ipaddr::Sockets.IPv4,
        port::Integer;
        name = genpublishername(),
    )
        local socket
        try
            socket = ZMQ.Socket(ctx, ZMQ.PUB)
        catch e
            if e isa ZMQ.StateError
                @error "Could not create socket for publisher $name. " * ZMQ.jl_zmq_error_str()
            end
            rethrow(e)
        end

        try
            ZMQ.bind(socket, "tcp://$ipaddr:$port")
        catch e
            if e isa ZMQ.StateError
                @error "Could not bind publisher $name to " *
                       tcpstring(ipaddr, port) *
                       ". " *
                       ZMQ.jl_zmq_error_str()
                close(socket)
            end
            rethrow(e)
        end
        @info "Publishing $name on: $(tcpstring(ipaddr, port)), isopen = $(isopen(socket))"
        new(socket, port, ipaddr, IOBuffer(), name)
    end
end
function Publisher(ctx::ZMQ.Context, ipaddr, port::Integer; name = genpublishername())
    if !(ipaddr isa Sockets.IPv4)
        ipaddr = Sockets.IPv4(ipaddr)
    end
    Publisher(ctx, ipaddr, port, name = name)
end
function Publisher(
    ctx::ZMQ.Context,
    ipaddr,
    port::AbstractString;
    name = genpublishername(),
)
    Publisher(ctx, ipaddr, parse(Int, port), name = name)
end
Base.isopen(pub::Publisher) = Base.isopen(pub.socket)
Base.close(pub::Publisher) = Base.close(pub.socket)

function publish(pub::Publisher, proto_msg::ProtoBuf.ProtoType)
    # Encode the message with protobuf
    msg_size = ProtoBuf.writeproto(pub.buffer, proto_msg)

    # Create a new message to be sent and copy the encoded protobuf bytes
    msg = ZMQ.Message(msg_size)
    copyto!(msg, 1, pub.buffer.data, 1, msg_size)

    # Send over ZMQ
    # NOTE: ZMQ will de-allocate the message allocated above, so garbage
    # collection should not be an issue here
    ZMQ.send(pub.socket, msg)

    # Move to the beginning of the buffer
    seek(pub.buffer, 0)
end

tcpstring(pub::Publisher) = tcpstring(pub.ipaddr, pub.port)