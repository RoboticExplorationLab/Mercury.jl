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

abstract type Subscriber end

Base.isopen(sub::Subscriber)::Nothing = error("The `isopen` method hasn't been implemented for your Subscriber yet!")
Base.close(sub::Subscriber)::Nothing = error("The `close` method hasn't been implemented for your Subscriber yet!")
# Base.can_close(sub::Subscriber)::Nothing = error("The `can_close` method hasn't been implemented for your Subscriber yet!")
getname(sub::Subscriber)::String = sub.name
getflags(sub::Subscriber)::SubscriberFlags = sub.flags

# Keep track of newly recieved message
has_new(sub::Subscriber)::Bool = getflags(sub).hasreceived
function got_new!(sub::Subscriber)
    flags = getflags(sub)
    flags.hasreceived = false
    return flags.hasreceived
end

function decode!(buf::ProtoBuf.ProtoType, bin_data)
    io = seek(convert(IOStream, bin_data), 0)
    ProtoBuf.readproto(io, buf)
end

function decode!(buf::AbstractVector{UInt8}, bin_data)
    for i = 1:min(length(buf), length(bin_data)) 
        buf[i] = bin_data[i];
    end
end

function receive(sub::Subscriber,
                 buf, 
                 write_lock::ReentrantLock = ReentrantLock())::Nothing
    error("The `receive` method hasn't been implemented for your Subscriber yet!")
end

function subscribe(sub::Subscriber,
                   buf, 
                   write_lock::ReentrantLock = ReentrantLock())::Nothing
    error("The `subscribe` method hasn't been implemented for your Subscriber yet!")
end

"""
Specifies a subcriber along with specific message type.
This is useful for tracking multiple messages at once
"""
struct SubscribedMessage
    msg::ProtoBuf.ProtoType  # Note this is an abstract type
    sub::Subscriber
    lock::ReentrantLock
    name::String

    function SubscribedMessage(msg::ProtoBuf.ProtoType, sub::Subscriber; name=getname(sub))
        new(msg, sub, ReentrantLock(), name)
    end
end
subscribe(submsg::SubscribedMessage) = subscribe(submsg.sub, submsg.msg, submsg.lock)
getname(submsg::SubscribedMessage) = submsg.name

"""
    on_new(func::Function, submsg::SubscribedMessage)
Helpful function for executing code blocks when a SubscribedMessage type has recieved a
new message on its Subscriber's Socket. The function func is expected to have a signature
of `func(msg::ProtoBuf.ProtoType)` where msg is the message which `submsg` has recieved.

Example:
```
on_new(nodeio.subs[1]) do msg
    println(msg.pos_x)
end
```
"""
function on_new(func::Function, submsg::SubscribedMessage)
    if has_new(submsg.sub)
        # TODO: is lock needed here
        # Lock Message while performing operations on it
        # lock(submsg.lock) do
            func(submsg.msg)
        # end
        got_new!(submsg.sub)
    end
end