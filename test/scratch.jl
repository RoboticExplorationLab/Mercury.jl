abstract type Node end

for pubsub in ((:publisher, :pubs), (:subscriber, :subs))
    @eval $(Symbol("get", pubsub[1]))(node::Node, index::Integer) =
        getIO(node).$(pubsub[2])[index]
    @eval function $(Symbol("get", pubsub[1]))(node::Node, name::String)
        index = findfirst(getIO(node).$(pubsub[2])) do msg
            getname(msg) == name
        end
        if !isnothing(index)
            return $(Symbol("get", pubsub[1]))(node, index)
        end
        return nothing
    end
    @eval $(Symbol("num", pubsub[1], "s"))(node::Node) = length(getIO(node).$(pubsub[2]))
end

# %%
for pubsub in ((:publisher, :pubs), (:subscriber, :subs))
    println(pubsub)

    # @eval $(Symbol("get", pubsub[1]))(node::Node, index::Integer) =
    #     getIO(node).$(pubsub[2])[index]
    println((Symbol("get", pubsub[1])))
end
