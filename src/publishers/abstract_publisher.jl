abstract type Publisher end

Base.isopen(sub::Publisher)::Nothing =
    error("The `isopen` method hasn't been implemented for your Publisher yet!")
Base.close(sub::Publisher)::Nothing =
    error("The `close` method hasn't been implemented for your Publisher yet!")
getname(pub::Publisher)::String = pub.name

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
publish(pubmsg::PublishedMessage) = publish(pubmsg.pub, pubmsg.msg)
getname(pubmsg::PublishedMessage) = pubmsg.name
