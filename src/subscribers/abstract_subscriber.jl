abstract type Subscriber end

Base.isopen(sub::Subscriber)::Nothing = error("The `isopen` method hasn't been implemented for your Subscriber yet!")
Base.close(sub::Subscriber)::Nothing = error("The `close` method hasn't been implemented for your Subscriber yet!")


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