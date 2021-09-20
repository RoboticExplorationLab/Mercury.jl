import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools
if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end

struct PubNode <: Hg.Node
    ctx::ZMQ.Context
    nodedata::Hg.NodeData
    test_msg::TestMsg
end

function PubNode()
    ctx = ZMQ.Context()
    test_msg = TestMsg(x = 10, y = 10, z = 10)
    nodedata = Hg.NodeData()
    PubNode(ctx, nodedata, test_msg)
end

function Hg.setupIO!(node::PubNode, nodeio::Hg.NodeIO)
    ctx = node.ctx
    addr = ip"127.0.0.1"
    port = 5555
    Hg.add_publisher!(nodeio, node.test_msg, ctx, addr, port)
    return nothing
end

function Hg.compute(node::PubNode)
    node.test_msg.x += 1
    node.test_msg.y += 2
    node.test_msg.z += 3
    Hg.publish(Hg.getIO(node).pubs[1])
    if (node.test_msg.x % 100) == 0
        println("Sent x value of ", node.test_msg.x)
    end
end

struct SubNode <: Hg.Node
    ctx::ZMQ.Context
    nodedata::Hg.NodeData
    test_msg::TestMsg
end

function SubNode(ctx = ZMQ.Context())
    test_msg = TestMsg(x=0, y=0, z=0)
    nodedata = Hg.NodeData()
    SubNode(ctx, nodedata, test_msg)
end

function Hg.setupIO!(node::SubNode, nodeio::Hg.NodeIO)
    ctx = node.ctx
    addr = ip"127.0.0.1"
    port = 5555
    Hg.add_subscriber!(nodeio, node.test_msg, ctx, addr, port)
end

function Hg.compute(node::SubNode)
    # x = 0
    # y = 0
    # z = 0
    # submsg = Hg.getIO(node).subs[1]
    # lock(submsg.lock) do
    #     x = node.test_msg.x
    #     y = node.test_msg.y
    #     z = node.test_msg.z
    # end
    # println("Received x = $x")
end

##
node = PubNode()
Hg.getoptions(node).rate = 500
# Hg.setupIO!(node, Hg.getIO(node))
Hg.closeall(node)
task = @async Hg.launch(node)
istaskdone(task)
istaskfailed(task)
wait(task)


##
using Base.Threads
subnode = SubNode()
Hg.getoptions(subnode).rate = 100
subtask = Threads.@spawn Hg.launch(subnode)
istaskdone(subtask)
istaskfailed(subtask)
fetch(subtask)
Hg.stopnode(subnode)
Hg.closeall(subnode)


Hg.stopnode(node)
Hg.closeall(node)