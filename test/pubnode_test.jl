# import Pkg; Pkg.activate(@__DIR__)
import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools

if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end

const ADDR = ip"127.0.0.1"
const PORT = 5555

struct PubNode <: Hg.Node
    # Required by Abstract Node type
    nodeio::Hg.NodeIO
    rate::Float64
    should_finish::Bool

    # ProtoBuf message
    test_msg::TestMsg

    function PubNode()
        pubNodeIO = Hg.NodeIO(ZMQ.Context())
        rate = 100
        should_finish = false

        test_msg = TestMsg(x = 10, y = 10, z = 10)
        test_msg_pub = Hg.ZmqPublisher(pubNodeIO.ctx, addr, port)
        Hg.add_publisher!(pubNodeIO, test_msg, test_msg_pub)

        return new(pubNodeIO, rate, should_finish,
                   test_msg)
    end
end

function Hg.compute(node::PubNode)
    node.test_msg.x += 1
    node.test_msg.y += 2
    node.test_msg.z += 3

    Hg.publish(Hg.getIO(node).pubs[1])
    if (node.test_msg.x % 100) == 0
        println("Sent x value of ", node.test_msg.x)
    end

    Hg.publish.(imuViconNodeIO.pubs)
end

##
node = PubNode()
Hg.getoptions(node).rate = 500
# Hg.setupIO!(node, Hg.getIO(node))
Hg.closeall(node)
task = @async Hg.launch(node)
istaskdone(task)