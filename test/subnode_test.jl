import Pkg;
Pkg.activate(@__DIR__);
import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools
if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end

struct SubNode <: Hg.Node
    ctx::ZMQ.Context
    nodedata::Hg.NodeData
    test_msg::TestMsg
end

function SubNode(ctx = ZMQ.Context())
    test_msg = TestMsg(x = 0, y = 0, z = 0)
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
using Base.Threads
subnode = SubNode()
Hg.getoptions(subnode).rate = 100
subtask = Threads.@spawn Hg.launch(subnode)
istaskdone(subtask)
istaskfailed(subtask)
fetch(subtask)
