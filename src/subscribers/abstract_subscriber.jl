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

    "# Of bytes of last message recieved"
    bytesrecieved::Int64 = 0
end

abstract type Subscriber end

Base.isopen(sub::Subscriber)::Nothing =
    error("The `isopen` method hasn't been implemented for your Subscriber yet!")
Base.close(sub::Subscriber)::Nothing =
    error("The `close` method hasn't been implemented for your Subscriber yet!")
# TODO: probably should delete this
forceclose(sub::Subscriber)::Nothing =
    error("The `forceclose` method hasn't been implemented for your Subscriber yet!")

getname(sub::Subscriber)::String = sub.name
getflags(sub::Subscriber)::SubscriberFlags = sub.flags
portstring(sub::Subscriber)::String = ""

# Keep track of newly recieved message
bytesreceived(sub::Subscriber)::Int64 = getflags(sub).bytesrecieved
has_new(sub::Subscriber)::Bool = getflags(sub).hasreceived

"""
Set the has received flag on subscriber to true
"""
function got_new!(sub::Subscriber)
    flags = getflags(sub)
    flags.hasreceived = true
    return flags.hasreceived
end

"""
Set the has received flag on subscriber to false
"""
function read_new!(sub::Subscriber)
    flags = getflags(sub)
    flags.hasreceived = false
    return flags.hasreceived
end


"""
Read in the byte data into the message container buf. Returns the number of bytes read
"""
function decode!(buf::ProtoBuf.ProtoType, bin_data::IOBuffer)
    bytes_read = length(bin_data.data)
    ProtoBuf.readproto(bin_data, buf)

    return bytes_read
end

function decode!(buf::AbstractVector{UInt8}, bin_data::IOBuffer)
    bytes_read = min(length(buf), bin_data.size)

    for i = 1:bytes_read
        buf[i] = bin_data.data[i]
    end

    return bytes_read
end

"""
Receive function, is expected to return true if a message was received, false otherwise
"""
function receive(sub::Subscriber, buf::MercuryMessage)::Bool
    error("The `receive` method hasn't been implemented for your Subscriber yet!")
end

"""
Specifies a subcriber along with specific message type.
This is useful for tracking multiple messages at once
"""
struct SubscribedMessage
    # Handle case in which listening for byte array or for protobuf (see decode!)
    msg::MercuryMessage
    sub::Subscriber          # Note this is an abstract type
    name::String

    function SubscribedMessage(
        msg::MercuryMessage,
        sub::Subscriber;
        name = getname(sub),
    )
        new(msg, sub, name)
    end
end

function receive(submsg::SubscribedMessage)::Bool
    # Check if we recieved a new message, if we do set has recieved flag to true
    if (receive(submsg.sub, submsg.msg))
        got_new!(submsg.sub)
    end
    return has_new(submsg.sub)
end

@inline getname(submsg::SubscribedMessage) = submsg.name
@inline getcomtype(submsg::SubscribedMessage) = getcomtype(submsg.sub)


function printstatus(sub::SubscribedMessage; indent = 0)
    prefix = " "^indent
    println(prefix, "Subscriber: ", getname(sub))
    println(prefix, "  Type: ", getcomtype(sub))
    println(prefix, "  Message Type: ", typeof(sub.msg))
    println(prefix, "  Is running? ", !isempty(sub.task) && !istaskdone(sub.task[end]))
    println(prefix, "  Is failed? ", !isempty(sub.task) && istaskfailed(sub.task[end]))
    println(prefix, "  Has received? ", getflags(sub.sub).hasreceived)
    println(prefix, "  Is Open? ", isopen(sub.sub))
end

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
        func(submsg.msg)

        read_new!(submsg.sub)
    end
end
