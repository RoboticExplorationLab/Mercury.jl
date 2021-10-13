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

    "Should the subscriber finish? Cleanest way to stop a subscriber task."
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

function receive(sub::Subscriber, buf, write_lock::ReentrantLock = ReentrantLock())::Nothing
    error("The `receive` method hasn't been implemented for your Subscriber yet!")
end

function subscribe(sub::Subscriber, buf, write_lock::ReentrantLock)
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

        if getflags(sub).should_finish[]
            @debug "[subscribe loop] Shutting Down subscriber $(getname(sub)) on: $(portstring(sub))."
        else
            @debug "[subscribe loop] Shutting Down subscriber $(getname(sub)) on: $(portstring(sub)). Socket was closed"
        end
        close(sub)
    catch err
        sub.flags.diderror = true
        close(sub)
        if !(err isa EOFError)  # catch the EOFError throw when force closing the socket
            @warn "Shutting Down subscriber $(getname(sub)) on: $(portstring(sub)). Subscriber errored out."
            rethrow(err)
        else
            @warn "Shutting Down subscriber $(getname(sub)) on: $(portstring(sub)). Force closing Subscriber."
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
    msg::Union{ProtoBuf.ProtoType,AbstractVector{UInt8}}
    sub::Subscriber          # Note this is an abstract type
    lock::ReentrantLock
    name::String
    task::Vector{Task}

    function SubscribedMessage(
        msg::Union{ProtoBuf.ProtoType,AbstractVector{UInt8}},
        sub::Subscriber;
        name = getname(sub),
    )
        new(msg, sub, ReentrantLock(), name, Task[])
    end
end
@inline subscribe(submsg::SubscribedMessage) =
    subscribe(submsg.sub, submsg.msg, submsg.lock)
@inline getname(submsg::SubscribedMessage) = submsg.name
@inline getcomtype(submsg::SubscribedMessage) = getcomtype(submsg.sub)
isrunning(submsg::SubscribedMessage) =
    !isempty(submsg.task) && !istaskdone(submsg.task[end])

# TODO: add a `close` method and modify the constructor to automatically create a subscriber

function launchtask(submsg::SubscribedMessage)
    push!(submsg.task, @async subscribe(submsg))
    return submsg.task[end]
end

# NOTE: this won't work until the receive is non-blocking (upcoming PR)
function stopsubscriber(submsg::SubscribedMessage)
    getflags(submsg.sub).should_finish[] = true
    wait(submsg.task[end])
end

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
        # Lock Message incase user performs operations on it
        lock(submsg.lock) do
            func(submsg.msg)
        end

        got_new!(submsg.sub)
    end
end
