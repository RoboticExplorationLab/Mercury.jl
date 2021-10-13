"""
Used for listening to VICON messages
"""
struct SerializedVICONcpp
    msgid::UInt8
    is_occluded::Bool
    position_scale::UInt16

    position_x::Float32
    position_y::Float32
    position_z::Float32

    quaternion_w::Float32
    quaternion_x::Float32
    quaternion_y::Float32
    quaternion_z::Float32

    time_us::UInt32
end
mutable struct SerializedVICON
    vicon::SerializedVICONcpp
end
Base.zero(::Type{SerializedVICON}) = SerializedVICON(
    SerializedVICONcpp(zero(UInt8), false, zero(UInt16), zeros(UInt32, 8)...),
)

"""
Specifies a subcriber along with specific message type.
This is useful for tracking multiple messages at once
"""
struct SubscribedVICON
    msg::SerializedVICON  # Note this is an abstract type
    sub::Subscriber
    name::String

    function SubscribedVICON(sub::Subscriber; name = getname(sub))
        msg = zero(SerializedVICON)
        new(msg, sub, name)
    end
end
subscribe(submsg::SubscribedVICON) = subscribe(submsg.sub, submsg.msg)
getname(submsg::SubscribedVICON) = submsg.name

function on_new(func::Function, submsg::SubscribedVICON)
    if has_new(submsg.sub)
        func(submsg.msg.vicon)

        got_new!(submsg.sub)
    end
end

"""
Useful functions for communicating with serial VICON
"""
function receive(sub::ZmqSubscriber, msg::SerializedVICON)
    if isopen(sub)
        sub.flags.isreceiving = true

        local bin_data
        lock(sub.socket_lock) do
            bin_data = ZMQ.recv(sub.socket)
            # @info "Got Vicon msg of size $(length(bin_data))"
            # Once blocking is finished we know we've recieved a new message
            sub.flags.hasreceived = true
            # Forces subscriber to conflate messages
            ZMQ.getproperty(sub.socket, :events)
        end
        sub.flags.isreceiving = false
        # Reinterpret serialized data as SerializedVICON message
        msg.vicon = reinterpret(SerializedVICONcpp, bin_data)[1]
    end
end

function subscribe(sub::ZmqSubscriber, msg::SerializedVICON)
    @info "$(sub.name): Listening for SerializedVICON message, on: $(portstring(sub))"

    try
        while isopen(sub)
            receive(sub, msg)
            GC.gc(false)
            yield()
        end
        @warn "Shutting Down subscriber $(getname(sub)) on: $(portstring(sub)). Socket was closed."
    catch err
        sub.flags.diderror = true
        close(sub)
        @warn "Shutting Down subscriber $(getname(sub)) on: $(portstring(sub))."
        @error err exception = (err, catch_backtrace())
    end

    return nothing
end
