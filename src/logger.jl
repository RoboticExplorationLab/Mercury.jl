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

struct Logger
    logs::Vector{SubscribedMessage}
    sub_tasks::Vector{Task}
    sub_log_files::

    # rate::Float64 = 100
    write_file::String =

    function NodeIO()
        new(PublishedMessage[], SubscribedMessage[], Task[])
    end
end

function add_log!(logger::Logger, msg::ProtoBuf.ProtoType, args...)
    push!(logger.logs, SubscribedMessage(msg, Subscriber(args...)))
end

# function add_serial_log!(logger::Logger, msg::ProtoBuf.ProtoType, args...)
#     push!(logger.logs, SubscribedMessage(msg, SerialSubscriber(args...)))
# end


log