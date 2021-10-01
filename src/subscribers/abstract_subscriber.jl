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

    "Tells the subscriber thread to shut down the task ASAP"
    should_finish::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
end

abstract type Subscriber end

Base.isopen(sub::Subscriber)::Nothing =
    error("The `isopen` method hasn't been implemented for your Subscriber yet!")
Base.close(sub::Subscriber)::Nothing =
    error("The `close` method hasn't been implemented for your Subscriber yet!")
forceclose(sub::Subscriber)::Nothing =
    error("The `forceclose` method hasn't been implemented for your Subscriber yet!")
# Base.can_close(sub::Subscriber)::Nothing = error("The `can_close` method hasn't been implemented for your Subscriber yet!")
getname(sub::Subscriber)::String = sub.name
getflags(sub::Subscriber)::SubscriberFlags = sub.flags
portstring(sub::Subscriber)::String = ""

# Keep track of newly recieved message
bytesreceived(sub::Subscriber)::Int64 = getflags(sub).bytesrecieved
has_new(sub::Subscriber)::Bool = getflags(sub).hasreceived
function got_new!(sub::Subscriber)
    flags = getflags(sub)
    flags.hasreceived = false
    return flags.hasreceived
end

function decode!(buf::ProtoBuf.ProtoType, bin_data)
    bytes_written = min(length(buf), length(bin_data))

    io = seek(convert(IOStream, bin_data), 0)
    ProtoBuf.readproto(io, buf)

    return bytes_written
end

function decode!(buf::AbstractVector{UInt8}, bin_data)
    bytes_written = min(length(buf), length(bin_data))
    for i = 1:min(length(buf), length(bin_data))
        buf[i] = bin_data[i]
    end

    return bytes_written
end

function receive(sub::Subscriber, buf, write_lock::ReentrantLock = ReentrantLock())::Nothing
    error("The `receive` method hasn't been implemented for your Subscriber yet!")
end

function subscribe(
    sub::Subscriber,
    buf,
    write_lock::ReentrantLock,
)
    @info "$(sub.name): Listening for message type: $(typeof(buf)), on: $(portstring(sub))"

    try
        while isopen(sub)
            receive(sub, buf, write_lock)
            GC.gc(false)
            yield()
            if getflags(sub).should_finish[]
                break
            end
        end
        close(sub)
        @warn "Shutting Down subscriber $(getname(sub)): $(portstring(sub)). Serial Port was closed."
    catch err
        sub.flags.diderror = true
        close(sub)
        @show typeof(err)
        if !(err isa EOFError)  # catch the EOFError throw when force closing the socket
            @warn "Shutting Down subscriber $(getname(sub)) on: $(portstring(sub)). Socket errored out."
            rethrow(err)
        else
            @warn "Shutting Down subscriber $(getname(sub)) on: $(portstring(sub)). Socket was forcefully closed."
        end
    end
    return nothing
end

"""
Specifies a subcriber along with specific message type.
This is useful for tracking multiple messages at once
"""
struct SubscribedMessage
    # Handle case in which listening for byte array or for protobuf (see decode!)
    msg::Union{ProtoBuf.ProtoType, AbstractVector{UInt8}}
    sub::Subscriber          # Note this is an abstract type
    lock::ReentrantLock
    name::String

    function SubscribedMessage(
        msg::Union{ProtoBuf.ProtoType, AbstractVector{UInt8}},
        sub::Subscriber;
        name = getname(sub),
    )
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
        # Lock Message incase user performs operations on it
        lock(submsg.lock) do
            func(submsg.msg)
        end

        got_new!(submsg.sub)
    end
end
