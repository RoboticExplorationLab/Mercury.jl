
Base.@kwdef mutable struct NodeOptions
    rate::Float64 = 100
end

Base.@kwdef mutable struct NodeFlags
    did_error::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
    is_running::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
    should_finish::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
end

"""
    NodeIO

Describes the input/output mechanisms for the node. Each node should store this type
internally and add the necessary I/O mechanisms inside of the `setupIO!(::NodeIO, ::Node)`
method.

I/O mechanisms are added to a `NodeIO` object via [`add_publisher!`](@ref) and
[`add_subscriber!`](@ref).
"""
struct NodeIO
    ctx::Union{Nothing,ZMQ.Context}
    pubs::Vector{PublishedMessage}
    subs::Vector{SubscribedMessage}
    opts::NodeOptions
    flags::NodeFlags

    function NodeIO(ctx::ZMQ.Context = ZMQ.context(); opts...)
        new(
            ctx,
            PublishedMessage[],
            SubscribedMessage[],
            NodeOptions(; opts...),
            NodeFlags(),
        )
    end
end

"""
    add_publisher!(nodeIO, msg, args...)

Adds / registers a publisher to `nodeIO`. This method should only be called once
per unique message, across all nodes in the network, since each message should only
ever have one publisher. The `msg` can be any `ProtoBuf.ProtoType` message (usually
generated using `ProtoBuf.protoc`). Since this is stored as an abstract `ProtoBuf.ProtoType`
type internally, the user should store the original type inside the node.  The remaining
arguments are passed directly to the constructor for [`Publisher`](@ref).

This function adds a new [`PublishedMessage`](@ref) to `nodeIO.pubs`. During the `compute`
    method, the user should modify the original concrete `msg` stored in the node. The
    data can then be published by calling `publish` on the corresponding `PublishedMessage`.

# Example
Inside of the node constructor:

    ...
    test_msg = TestMsg(x = 1, y = 2, z= 3)
    ...

Inside of `setupIO!`:

    ...
    ctx = ZMQ.Context()
    ipaddr = ip"127.0.0.1"
    port = 5001
    add_publisher!(nodeIO, node.test_msg, ctx, ipaddr, port, name="TestMsg_publisher")
    ...

Inside of `compute`:

    ...
    node.test_msg.x = 1  # modify the message as desired
    publish(getIO(node).pubs[1])  # or whichever is the correct index
    ...

"""
function add_publisher!(nodeio::NodeIO, msg::MercuryMessage, pub::Publisher)
    push!(nodeio.pubs, PublishedMessage(msg, pub))
end

"""
    add_subscriber!(nodeIO, msg, args...)

Adds / registers a subscriber to `nodeIO`. The `msg` can be any
`ProtoBuf.ProtoType` message (usually generated using `ProtoBuf.protoc`). Since
this is stored as an abstract `ProtoBuf.ProtoType` type internally, the user
should store the original type inside the node.  The remaining arguments are
passed directly to the constructor for [`Subscriber`](@ref).

This function adds a new [`SubscribedMessage`](@ref) to `nodeIO.subs`. A
separate asynchronous task is created for each subscriber when the node is
launched.  During the `compute` method, the user can access the latest data by
reading from the message stored in their node. To avoid data races and minimize
synchronization, it's usually best practice to obtain the lock on the message
(stored in `SubscribedMessage`) and copy the data to a local variable (likely
also stored in the node) that can be used by the rest of the `compute` method
without worrying about the data being overwritted by the ongoing subscriber
task.

# Example
In the node constructor:

    ...
    test_msg = TestMessage(x = 0, y = 0, z = 0)
    ...

In `setupIO!`:

    ...
    ctx = ZMQ.Context()
    ipaddr = ip"127.0.0.1"
    port = 5001
    add_subscriber!(nodeIO, node.test_msg, ctx, ipaddr, port, name = "TestMsg_subscriber")
    ...

In `compute`:

    ...
    testmsg = getIO(node).subs[1]  # or whichever is the correct index
    lock(testmsg.lock) do
        node.local_test_msg = node.test_msg  # or convert to a different type
    end
    # use node.local_test_msg in the rest of the code
    ...
"""
function add_subscriber!(nodeio::NodeIO, msg::MercuryMessage, sub::Subscriber)
    push!(nodeio.subs, SubscribedMessage(msg, sub))
end


"""
    Node

A independent process that communicates with other processes via pub/sub ZMQ channels.
The process is assumed to run indefinately.

# Defining a new Node
Each node should contain a `NodeData` element, which stores a list of the publishers
and subscribers and some other associated data.

The publisher and subscribers for the node should be "registered" with the `NodeData`
using the `add_publisher!` and `add_subscriber!` methods. This allows the subscribers to
be automatically launched as separate tasks when launching the nodes.

The constructor for the node should initialize any variables and register the needed
publishers and subscribers with `NodeData`.

Each loop of the process will call the `compute` method once, which needs to be
implemented by the user. A lock for each subscriber task is created in `NodeData.sub_locks`.
It's recommended that the user obtains the lock and copies the data into a local variable
for internal use by the `compute` function.

# Launching the node
The blocking process that runs the node indefinately is called via `run(node)`. It's
recommended that this is launched asynchronously via

    node_task = @task run(node)
    schedule(node_task)
"""
abstract type Node end

##############################
# REQUIRED INTERFACE
##############################
compute(::Node)::Nothing =
    error("The `compute` method hasn't been implemented for your node yet!")

# NOTE: This method may be automatically defined using codegen and the TOML file
#       in the future
setupIO!(::Node, ::NodeIO) =
    error("The `setupIO` method hasn't been implemented for your node yet!")

##############################
# OPTIONAL INTERFACE
##############################
startup(::Node)::Nothing = nothing
finishup(::Node)::Nothing = nothing
getcontext(node::Node)::Union{Nothing,ZMQ.Context} = getIO(node).ctx
getIO(node::Node)::NodeIO = node.nodeio

function getname(::T) where {T<:Node}
    # Note that this only works well when each node is only instantiated once
    return string(T)
end

##############################
# PROVIDED INTERFACE (don't change)
##############################
getoptions(node::Node) = getIO(node).opts
getflags(node::Node) = getIO(node).flags
getrate(node::Node)::Float64 = getoptions(node).rate
function shouldnodefinish(node::Node)::Bool
    return getflags(node).should_finish[]
end

function stopnode(node::Node; timeout = 1.0)
    getflags(node).should_finish[] = true
    t_start = time()
    while (time() - t_start < timeout)
        yield()
        if !(getflags(node).is_running[])
            return true
        end
    end
    # If it doesn't stop in time, forcefully close the node
    @warn "Node timed out. Forcefully closing the node."
    closeall(node)
    return false
end

publishers(node::Node) = getIO(node).pubs
subscribers(node::Node) = getIO(node).subs

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

"""
    numsubscribers(node)

Get the number of ZMQ subscribers attached to the node
"""
numsubscribers

"""
    numpublishers(node)

Get the number of ZMQ publishers attached to the node
"""
numpublishers

"""
    getsubscriber(node, index)
    getsubscriber(node, name)

Get a  [`SubscribedMessage`](@ref) attached to `node`, either by it's integer index or it's name.
"""
getsubscriber

"""
    getpublisher(node, index)
    getpublisher(node, name)

Get a  [`PublishedMessage`](@ref) attached to `node`, either by it's integer index or it's name.
"""
getpublisher

"""
    launch(node)

Run the main loop of the node indefinately. This method automatically sets up any necessary
subscriber tasks and then calls the `compute` method at a fixed rate.

This method should typically be wrapped in an `@async` or `@spawn` call.
"""
function launch(node::Node)
    try
        rate = getrate(node)
        lrl = LoopRateLimiter(rate)

        # Run any necessary startup
        startup(node)

        getflags(node).is_running[] = true

        @rate while !shouldnodefinish(node)
            # Check the subscribers for new messages
            poll_subscribers(node)

            # Check the subscribers for new messages
            compute(node)

            GC.gc(false)
            yield()
        end lrl
        @info "Closing node $(getname(node))"
        finishup(node)
        closeall(node)
    catch err
        if err isa InterruptException
            @info "Closing node $(getname(node)). Got Keyboard Interrupt."
        else
            @warn "Closing node $(getname(node)). Closed with error."
            @error "Node failed" exception = (err, catch_backtrace())

            Base.display_error(err)
            Base.show_exception_stack(err, stacktrace(catch_backtrace()))
            getflags(node).did_error[] = true
            rethrow(err)
        end
        finishup(node)
        closeall(node)
    end
    getflags(node).is_running[] = false
end

function poll_subscribers(node::Node)
    nodeio = getIO(node)

    for submsg in nodeio.subs
        receive(submsg)
    end
end

function closeall(node::Node)
    @info "Closing down all of $(getname(node))'s NodeIO connections"

    nodeio = getIO(node)
    # Close publishers and subscribers
    for submsg in nodeio.subs
        close(submsg.sub)
    end
    for pubmsg in nodeio.pubs
        close(pubmsg.pub)
    end

    return nothing
end

function node_sockets_are_open(node::Node)
    nodeio = getIO(node)
    return (
        all([isopen(submsg.sub) for submsg in nodeio.subs]) && all([isopen(pubmsg.pub) for pubmsg in nodeio.pubs])
    )
end

#! format: off
function printstatus(node::Node)
    is_running = getflags(node).is_running[]
    printstyled("Node name: ", bold=true); println(getname(node))
    printstyled("  Is running? ", bold=true); println(is_running)
    if !is_running
        printstyled("  Did error? ", bold=true); println(getflags(node).did_error[])
    end
    if (numpublishers(node) > 0)
        printstyled("  Publishers:\n", bold=true)
        for pub in publishers(node)
            printstatus(pub, indent=4)
        end
    end
    if (numsubscribers(node) > 0)
        printstyled("  Subscribers:\n", bold=true)
        for sub in subscribers(node)
            printstatus(sub, indent=4)
        end
    end
end
#! format: on
