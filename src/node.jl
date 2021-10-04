
Base.@kwdef mutable struct NodeOptions
    rate::Float64 = 100
    default_addr::Sockets.IPv4 = ip"127.0.0.1"
    heartbeat_enable::Bool = false
    heartbeat_addr::Sockets.IPv4 = default_addr
    heartbeat_port::Int = getdefaultport()
    heartbeat_rate::Float64 = 1.0  # Hz
    heartbeat_print_rate_enable::Bool = false
end

Base.@kwdef mutable struct NodeFlags
    did_error::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
    is_running::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
    should_finish::Threads.Atomic{Bool} = Threads.Atomic{Bool}(false)
end

"""
    NodeHeartbeat

Contains basic information about the node, and is responsible for publishing a ZMQ 
message with this information, if the node option `heartbeat_enable` is set to true.

The heartbeat is published at a given rate, specified by the `heartbeat_rate` node option.
For best results, this should divide evenly into the higher rate at which the node runs.

The address and port of the publisher are also specified in the node options.

As part of the published info, the average rate of the node is calculated by this 
struct between calls to `publish(pub, heartbeat, node)`. This is all handled internally 
in the `launch` method for the node, and should be transparent to the user, who should 
only indirectly interact with this type via the corresponding node options.
"""
mutable struct NodeHeartbeat
    print_rate_enable::Bool
    t_start::UInt64
    cnt::Int
    msg::NodeInfo
    rate::Float64
    function NodeHeartbeat(ctx::ZMQ.Context, opts::NodeOptions)
        print_rate_enable = opts.heartbeat_print_rate_enable
        t_start = UInt64(0)
        cnt = 0
        msg = NodeInfo()
        rate = opts.heartbeat_rate
        new(print_rate_enable, t_start, cnt, msg, rate)
    end
end

function init(hbt::NodeHeartbeat)
    hbt.t_start = time_ns()
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
    # sp::Union{Nothing,LibSerialPort.SerialPort}
    pubs::Vector{PublishedMessage}
    subs::Vector{SubscribedMessage}
    opts::NodeOptions
    flags::NodeFlags
    heartbeat::NodeHeartbeat

    function NodeIO(ctx::ZMQ.Context = ZMQ.context(); opts...)
        opts = NodeOptions(; opts...)
        new(
            ctx,
            PublishedMessage[],
            SubscribedMessage[],
            opts,
            NodeFlags(),
            NodeHeartbeat(ctx, opts),
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
function add_publisher!(nodeio::NodeIO, msg::ProtoBuf.ProtoType, pub::Publisher)
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
function add_subscriber!(nodeio::NodeIO, msg::ProtoBuf.ProtoType, sub::Subscriber)
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
setupIO!(node::Node) =
    error("The `setupIO` method hasn't been implemented for your node yet!")

##############################
# OPTIONAL INTERFACE
##############################
startup(::Node)::Nothing = nothing
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
function isnodedone(node::Node)::Bool
    nodeio = getIO(node)
    all_running = all(isrunning.(nodeio.subs))
    return getflags(node).should_finish[] || !all_running
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
    rate = getrate(node)
    lrl = LoopRateLimiter(rate)
    opts = getoptions(node)
    heartbeat = getIO(node).heartbeat

    # Launch the subscriber tasks asynchronously
    start_subscribers(node)

    # Run any necessary startup
    startup(node)

    # Initialize the heartbeat publisher, if needed
    if opts.heartbeat_enable
        init(heartbeat)
        heartbeat_pub = ZmqPublisher(
            getcontext(node),
            opts.heartbeat_addr,
            opts.heartbeat_port,
            name = getname(node) * "_heartbeat_pub",
        )
    end

    getflags(node).is_running[] = true
    try
        @rate while !isnodedone(node)

            compute(node)

            GC.gc(false)
            yield()

            # publish the node heartbeat, if necessary
            if opts.heartbeat_enable
                publish(heartbeat_pub, heartbeat, node)
            end

        end lrl
        @info "Closing node $(getname(node))"
        closeall(node)
    catch err
        if err isa InterruptException
            @info "Closing node $(getname(node)). Got Keyboard Interrupt."
        else
            @warn "Closing node $(getname(node)). Closed with error."
            Base.display_error(err)
            println()
            getflags(node).did_error[] = true
            closeall(node)
            getflags(node).is_running[] = false
            rethrow(err)
        end
        closeall(node)
    end
    # Close the heartbeat publisher if it was set up
    if opts.heartbeat_enable
        close(heartbeat_pub)
    end
    getflags(node).is_running[] = false
end

function start_subscribers(node::Node)
    nodeio = getIO(node)

    for submsg in nodeio.subs
        launchtask(submsg)
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
    # Wait for async tasks to finish
    for submsg in nodeio.subs
        wait(submsg.task[end])
        pop!(submsg.task)
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

function publish(heartbeat_pub, hbt::NodeHeartbeat, node::Node)
    ns_elapsed = time_ns() - hbt.t_start
    s_elapsed = ns_elapsed * 1e-9
    if s_elapsed > (1 / hbt.rate)
        # Calculate the average rate since the last publish
        avg_rate = hbt.cnt / s_elapsed

        # Update the message fields
        hbt.msg.name = getname(node)
        hbt.msg.num_publishers = numpublishers(node)
        hbt.msg.num_subscribers = numsubscribers(node)
        hbt.msg.all_sockets_open = node_sockets_are_open(node)
        hbt.msg.rate = avg_rate
        if hbt.print_rate_enable
            println("Average rate: ", avg_rate, "Hz")
        end

        # Publish the NodeInfo message
        @debug "Publishing heartbeat..."
        publish(heartbeat_pub, hbt.msg)

        hbt.t_start = time_ns()
        hbt.cnt = 0
    end
    hbt.cnt += 1
end
