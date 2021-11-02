Base.@kwdef mutable struct PublisherFlags
    "Is the publisher currently sending data"
    has_published::Bool = false

    "Did the publisher exit with an error"
    diderror::Bool = false

    "# Of bytes of last message sent"
    bytespublished::Int64 = 0
end

abstract type Publisher end

Base.isopen(sub::Publisher)::Nothing =
    error("The `isopen` method hasn't been implemented for your Publisher yet!")
Base.close(sub::Publisher)::Nothing =
    error("The `close` method hasn't been implemented for your Publisher yet!")
@inline getname(pub::Publisher)::String = pub.name
@inline getflags(pub::Publisher)::PublisherFlags = pub.flags
portstring(sub::Publisher)::String = error("The `portstring` method hasn't been implemented for your Publisher yet!")


"""
Write out the byte data into the message container buf. Returns the number of bytes written
"""
function encode!(buf::ProtoBuf.ProtoType, bin_data::IOBuffer)
    bytes_written = ProtoBuf.writeproto(bin_data, buf)

    return bytes_written
end

function encode!(buf::AbstractVector{UInt8}, bin_data::IOBuffer)
    bytes_written = min(length(buf), bin_data.size)
    copyto!(bin_data.data, 1, buf, 1, bytes_written)

    return bytes_written
end

function publish(pub::Publisher, msg::MercuryMessage)::Nothing
    throw(
        MercuryException(
            "The `publish` method hasn't been implemented for your Publisher yet!",
        ),
    )
end

"""
Specifies a publisher along with specific message type.
This is useful for tracking multiple messages at once
"""
struct PublishedMessage
    msg::MercuryMessage
    pub::Publisher
    name::String
    function PublishedMessage(msg::MercuryMessage, pub::Publisher; name = getname(pub))
        new(msg, pub, name)
    end
end
@inline publish(pubmsg::PublishedMessage) = publish(pubmsg.pub, pubmsg.msg)
@inline getname(pubmsg::PublishedMessage) = pubmsg.name
@inline getcomtype(pub::PublishedMessage) = getcomtype(pub.pub)

# TODO: add a `close` method and modify the constructor to automatically create a subscriber

function printstatus(pub::PublishedMessage; indent = 0)
    prefix = " "^indent
    println(prefix, "Publisher: ", getname(pub))
    println(prefix, "  Type: ", getcomtype(pub))
    println(prefix, "  Message Type: ", typeof(pub.msg))
    println(prefix, "  Has published? ", getflags(pub.pub).has_published[])
    println(prefix, "  Is Open? ", isopen(pub.pub))
end
