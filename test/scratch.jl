t_start = time_ns()

import Mercury as Hg
using ZMQ
using Sockets

using StaticArrays
using LinearAlgebra

if !isdefined(@__MODULE__, :TestMsg)
    include(joinpath(pkgdir(Hg), "test", "jlout", "test_msg_pb.jl"))
end

mutable struct SimpleNode <: Hg.Node
    ctx::ZMQ.Context   # NOTE: can we get rid of needing to store the ZMQ context?
    nodeio::Hg.NodeIO
    test_msg::TestMsg

    start_time::Float64
    end_time::Float64

    debug::Bool

    function SimpleNode(ctx; rate = 10, debug = false)
        test_msg = TestMsg(x = 0, y = 0, z = 0)
        nodeio = Hg.NodeIO(rate = rate)

        start_time = time()
        end_time = time()

        new(ctx, nodeio, test_msg, start_time, end_time, debug)
    end
end

function Hg.setupIO!(node::SimpleNode, nodeio::Hg.NodeIO)
    # Create a publisher
    ctx = node.ctx
    addr = ip"127.0.0.1"
    port = 5555
    pub = Hg.ZmqPublisher(ctx, addr, port, name = "test_pub")
    # Register the publisher to publish the `TestMsg` stored in the node
    Hg.add_publisher!(nodeio, node.test_msg, pub)
end

function Hg.compute(node::SimpleNode)
    # Update the internal message
    A = @SMatrix rand(3, 3)
    A = A'A
    Achol = cholesky(A)
    b = SA[node.test_msg.x, node.test_msg.y, node.test_msg.z]
    x = Achol \ b
    node.test_msg.x += 1
    node.test_msg.y = x[2]
    node.test_msg.z = x[3]

    if (node.test_msg.x % node.nodeio.opts.rate) == 0
        node.end_time = time()
        println("Rate: ", node.nodeio.opts.rate / (node.end_time - node.start_time))
        node.start_time = time()
    end

    # Publish the message
    #   Mercury will automatically encode the message as a string of bytes and send it over ZMQ
    Hg.publish.(Hg.getIO(node).pubs)  # NOTE: can we make this easier, maybe by using a Dict?

    if (node.test_msg.x % node.nodeio.opts.rate) == 0
        println("Sent x value of ", node.test_msg.x)
    end
end

function launch_simple_node(; rate = 10, time = 5)
    node = SimpleNode(ZMQ.context(), rate = rate)
    Hg.setupIO!(node, Hg.getIO(node))

    @time Hg.compute(node)

    t_since_start = (time_ns() - t_start) / 1e9
    println("Took $t_since_start seconds to precompile.")
    task = @async Hg.launch(node)
    sleep(10)
    Hg.stopnode(node)
    node
end

# %%
launch_simple_node(rate = 1000)
