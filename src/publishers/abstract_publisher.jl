abstract type Publisher end

Base.isopen(sub::Publisher)::Nothing = error("The `isopen` method hasn't been implemented for your Publisher yet!")
Base.close(sub::Publisher)::Nothing = error("The `close` method hasn't been implemented for your Publisher yet!")

function publish(pub::Publisher,
                 proto_msg::ProtoBuf.ProtoType)::Nothing
    error("The `receive` method hasn't been implemented for your Publisher yet!")
end
