"""
    NodeOptions

User-modifiable options for controlling the behavior of the node.
"""
Base.@kwdef mutable struct NodeOptions
    rate::Float64 = 100 # Hz
    gc_frequency::Int = 1
    rate_print_period::Float64 = 1.0 # seconds
    enable_rate_print::Bool = true
end


"""
    NodeFlags

Internally-modified flags maintained by the node. These should not ever be changed 
by the user, but can be read as needed to obtain high-level information about the 
status of the node, especially if it is running in a separate process.
"""
Base.@kwdef mutable struct NodeFlags
    "Should the node finish executing"
    should_finish::Bool = false

    "Has `setupIO!` been called"
    is_io_setup::Bool = false
end

struct PublishedMessage
    msg::ProtoBuf.ProtoType
    pub::Publisher
    name::String
    function PublishedMessage(msg::ProtoBuf.ProtoType, pub::Publisher; name=getname(pub))
        new(msg, pub, name)
    end
end
publish(pubmsg::PublishedMessage) = publish(pubmsg.pub, pubmsg.msg)
getname(pubmsg::PublishedMessage) = pubmsg.name

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

"""
    NodeIO

Describes the input/output mechanisms for the node. Each node should store this type 
internally and add the necessary I/O mechanisms inside of the `setupIO!(::NodeIO, ::Node)`
method.

I/O mechanisms are added to a `NodeIO` object via [`add_publisher!`](@ref) and 
[`add_subscriber!`](@ref). 
"""
struct NodeIO
    pubs::Vector{PublishedMessage}
    subs::Vector{SubscribedMessage}
    sub_tasks::Vector{Task}
    function NodeIO()
        new(PublishedMessage[], SubscribedMessage[], Task[])
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
function add_publisher!(nodeio::NodeIO, msg::ProtoBuf.ProtoType, args...)
    push!(nodeio.pubs, PublishedMessage(msg, Publisher(args...)))
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
function add_subscriber!(nodeio::NodeIO, msg::ProtoBuf.ProtoType, args...)
    push!(nodeio.subs, SubscribedMessage(msg, Subscriber(args...)))
end

"""
    NodeData

Each user-implemented node should include this struct to include all the data
required by the interface. The user should define the `getnodedata` method on their
node (defaults to extracting the `nodedata` field).
"""
struct NodeData
    nodeIO::NodeIO
    options::NodeOptions
    flags::NodeFlags
    rate_info::RateInfo
    function NodeData()
        new(NodeIO(), NodeOptions(), NodeFlags(), RateInfo())
    end
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

# These methods must be implemented
compute(::Node)::Nothing =
    error("The `compute` method hasn't been implemented for your node yet!")

# NOTE: This method may be automatically defined using codegen and the TOML file 
#       in the future
setupIO!(::Node, ::NodeIO) =
    error("The `setupIO` method hasn't been implemented for your node yet!")

# These methods can be overwritten as needed
startup(::Node)::Nothing = nothing
getnodedata(node::Node)::NodeData = node.nodedata

function getname(::T) where {T <: Node}
    # Note that this only works well when each node is only instantiated once
    return string(T)
end

# These methods should not be changed
getrate(node::Node)::Float64 = getoptions(node).rate
getoptions(node::Node)::NodeOptions = getnodedata(node).options 
getflags(node::Node)::NodeFlags = getnodedata(node).flags
getIO(node::Node)::NodeIO = getnodedata(node).nodeIO 
isnodedone(node::Node)::Bool = getflags(node).should_finish 

using Base.Threads

function launch(node::Node)
    nodeopts = getoptions(node)

    rate_info = getnodedata(node).rate_info
    init(rate_info, getname(node))
    rate_info.enable = nodeopts.enable_rate_print
    rate_print_period = nodeopts.rate_print_period
    rate_info.num_batch = round(Int, rate_print_period * nodeopts.rate)
    @show rate_info.num_batch

    getflags(node).should_finish = false
    if !getflags(node).is_io_setup
        setupIO!(node, getIO(node))
    end
    getflags(node).is_io_setup = true
    nodeio = getIO(node)::NodeIO

    # Launch the subscriber tasks asynchronously
    for submsg in nodeio.subs
        push!(nodeio.sub_tasks, Threads.@spawn subscribe(submsg))
    end

    # Run any necessary startup
    startup(node)

    lrl = LoopRateLimiter(nodeopts.rate)

    gc_count = 1
    try
        @rate while !isnodedone(node)
            compute(node)

            if gc_count == nodeopts
                GC.gc(false)
                gc_count = 0
            end
            gc_count += 1

            printrate(rate_info)
            yield()
        end lrl
        @info "Closing node $(getname(node))"
    catch e
        # Close publishers and subscribers
        for submsg in nodeio.subs
            forceclose(submsg.sub)
        end
        for pubmsg in nodeio.pubs
            close(pubmsg.pub)
        end

        # Wait for async tasks to finish
        for subtask in nodeio.sub_tasks
            wait(subtask)
        end

        if e isa InterruptException
            @info "Closing node $(getname(node))"
        else
            rethrow(e)
        end
    end
end

function stopnode(node::Node)
    getflags(node).should_finish = true
end

function closeall(node::Node)
    nodeio = getIO(node)
    for submsg in nodeio.subs
        close(submsg.sub)
    end
    for pubmsg in nodeio.pubs
        close(pubmsg.pub)
    end
    for subtask in nodeio.sub_tasks
        wait(subtask)
    end
    empty!(nodeio.sub_tasks) 
    return nothing 
end