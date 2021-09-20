abstract type Subscriber end

Base.isopen(sub::Subscriber)::Nothing = error("The `isopen` method hasn't been implemented for your Subscriber yet!")
Base.close(sub::Subscriber)::Nothing = error("The `close` method hasn't been implemented for your Subscriber yet!")
# Base.can_close(sub::Subscriber)::Nothing = error("The `can_close` method hasn't been implemented for your Subscriber yet!")
getname(sub::Subscriber)::String = sub.name

function receive(sub::Subscriber,
                 proto_msg::ProtoBuf.ProtoType,
                 write_lock = ReentrantLock())::Nothing
    error("The `receive` method hasn't been implemented for your Subscriber yet!")
end

function subscribe(sub::Subscriber,
                   proto_msg::ProtoBuf.ProtoType,
                   write_lock = ReentrantLock())::Nothing
    error("The `subscribe` method hasn't been implemented for your Subscriber yet!")
end


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

getflags(sub::Subscriber)::SubscriberFlags = sub.flags


"""
Specifies a subcriber along with specific message type.
This is useful for tracking multiple messages at once
"""
struct SubscribedMessage
    msg::ProtoBuf.ProtoType  # Note this is an abstract type
    sub::Subscriber
    lock::ReentrantLock
    name::String
    function SubscribedMessage(msg::ProtoBuf.ProtoType, sub::Subscriber; name=Subscribers.getname(sub))
        new(msg, sub, ReentrantLock(), name)
    end
end
subscribe(submsg::SubscribedMessage) = Subscribers.subscribe(submsg.sub, submsg.msg, submsg.lock)
getname(submsg::SubscribedMessage) = submsg.name
