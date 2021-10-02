Base.@kwdef mutable struct PublisherFlags
    has_published::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
end

abstract type Publisher end

Base.isopen(sub::Publisher)::Nothing =
    error("The `isopen` method hasn't been implemented for your Publisher yet!")
Base.close(sub::Publisher)::Nothing =
    error("The `close` method hasn't been implemented for your Publisher yet!")
getname(pub::Publisher)::String = pub.name
getflags(pub::Publisher)::PublisherFlags = pub.flags

function publish(pub::Publisher, proto_msg::ProtoBuf.ProtoType)::Nothing
    throw(
        MercuryException(
            "The `receive` method hasn't been implemented for your Publisher yet!",
        ),
    )
end

"""
Specifies a publisher along with specific message type.
This is useful for tracking multiple messages at once
"""
struct PublishedMessage
    msg::ProtoBuf.ProtoType
    pub::Publisher
    name::String
    function PublishedMessage(msg::ProtoBuf.ProtoType, pub::Publisher; name = getname(pub))
        new(msg, pub, name)
    end
end
@inline publish(pubmsg::PublishedMessage) = publish(pubmsg.pub, pubmsg.msg)
@inline getname(pubmsg::PublishedMessage) = pubmsg.name
@inline getcomtype(pub::PublishedMessage) = getcomtype(pub.pub)

# TODO: add a `close` method and modify the constructor to automatically create a subscriber

function printstatus(pub::PublishedMessage; indent=0)
    prefix = " " ^ indent
    println(prefix, "Publisher: ", getname(pub))
    println(prefix, "  Type: ", getcomtype(pub))
    println(prefix, "  Message Type: ", typeof(pub.msg))
    println(prefix, "  Has published? ", getflags(pub.pub).has_published[])
end