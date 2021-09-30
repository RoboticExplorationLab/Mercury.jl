import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools
if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end

mutable struct PubNode <: Hg.Node
    ctx::ZMQ.Context
    nodeio::Hg.NodeIO
    test_msg::TestMsg
    should_finish::Bool
end

function PubNode(ctx)
    test_msg = TestMsg(x = 10, y = 10, z = 10)
    nodedata = Hg.NodeIO()
    PubNode(ctx, nodedata, test_msg, false)
end

function Hg.setupIO!(node::PubNode, nodeio::Hg.NodeIO)
    ctx = node.ctx
    addr = ip"127.0.0.1"
    port = 5555
    pub = Hg.ZmqPublisher(ctx, addr, port, name="test_pub")
    empty!(nodeio.pubs)
    Hg.add_publisher!(nodeio, node.test_msg, pub)
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
Hg.getrate(::PubNode) = 10

mutable struct SubNode <: Hg.Node
    ctx::ZMQ.Context
    nodeio::Hg.NodeIO
    test_msg::TestMsg
    should_finish::Bool
end

function SubNode(ctx = ZMQ.Context())
    test_msg = TestMsg(x=0, y=0, z=0)
    nodedata = Hg.NodeIO()
    SubNode(ctx, nodedata, test_msg, false)
end

function Hg.setupIO!(node::SubNode, nodeio::Hg.NodeIO)
    ctx = node.ctx
    addr = ip"127.0.0.1"
    port = 5555
    sub = Hg.ZmqSubscriber(ctx, addr, port)
    empty!(nodeio.subs)
    empty!(nodeio.sub_tasks)
    Hg.add_subscriber!(nodeio, node.test_msg, sub)
end

Hg.getrate(::SubNode) = 10

function Hg.compute(node::SubNode)
    x = node.test_msg.x
    y = node.test_msg.y
    z = node.test_msg.z
    submsg = Hg.getIO(node).subs[1]
    lock(submsg.lock) do
        x = node.test_msg.x
        y = node.test_msg.y
        z = node.test_msg.z
    end
    println("Received x = $x")
end

## Initialize publisher
ctx = ZMQ.Context()
node = PubNode(ctx)
Hg.setupIO!(node, Hg.getIO(node))

## Initialize subscriber
using Base.Threads
subnode = SubNode()
Hg.setupIO!(subnode, Hg.getIO(subnode))
sub = Hg.getIO(subnode).subs[1]
@test isopen(sub.sub)

## Launch tasks
task = @async Hg.launch(node)
@test !istaskdone(task)
@test !istaskfailed(task)
@test Hg.node_sockets_are_open(node)

subnode.should_finish = false 
subtask = Threads.@spawn Hg.launch(subnode)
@test !istaskdone(subtask)
@test !istaskfailed(subtask)
@test Hg.node_sockets_are_open(subnode)

##
sleep(1)
subnode.should_finish = true
node.should_finish = true

sleep(0.5)
pub = node.nodeio.pubs[1]
@test !isopen(pub.pub)
sub = Hg.getIO(subnode).subs[1]
@test !isopen(sub.sub)
@test isempty(subnode.nodeio.sub_tasks)

dx = node.test_msg.x - subnode.test_msg.x
dy = node.test_msg.y - subnode.test_msg.y
dz = node.test_msg.z - subnode.test_msg.z
@test abs(dx) <= 1
@test abs(dy) <= 2
@test abs(dz) <= 3
@show node.test_msg.x