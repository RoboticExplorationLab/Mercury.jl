# Node for communicating with the Jetson (run on the ground station)
module DummyNodes
    import Mercury as Hg
    using ZMQ
    using Printf
    using StaticArrays
    using TOML

    joinpath(@__DIR__, "jlout", "test_msg_pb.jl")

    mutable struct PubNode <: Hg.Node
        # Required by Abstract Node type
        nodeio::Hg.NodeIO
        rate::Float64
        should_finish::Bool

        # Specific to GroundLinkNode
        # ProtoBuf Messages
        test::TestMsg

        # Random
        debug::Bool

        function PubNode(test_pub_ip::String, test_pub_port::String,
                         rate::Float64, debug::Bool)
            # Adding the Ground Vicon Subscriber to the Node
            pubNodeIO = Hg.NodeIO()
            rate = rate
            should_finish = false

            ctx = Context(1)

            test = TestMsg(x=0., y=0., z=0.)
            test_pub = Hg.ZmqPublisher(ctx, test_pub_ip, test_pub_port)
            Hg.add_publisher!(pubNodeIO, test, test_pub)

            debug = debug

            return new(pubNodeIO, rate, should_finish,
                       test,
                       debug)
        end
    end

    function Hg.compute(node::PubNode)
        nodeio = Hg.getIO(node)

        node.vicon.pos_x += 1
        println("Published")

        Hg.publish.(nodeio.pubs)
    end

    mutable struct SubNode <: Hg.Node
        # Required by Abstract Node type
        nodeio::Hg.NodeIO
        rate::Float64
        should_finish::Bool

        # Specific to GroundLinkNode
        # ProtoBuf Messages
        test::TestMsg

        # Random
        debug::Bool

        function SubNode(test_sub_ip::String, test_sub_port::String,
                         rate::Float64, debug::Bool)
            # Adding the Ground Vicon Subscriber to the Node
            pubNodeIO = Hg.NodeIO()
            rate = rate
            should_finish = false

            ctx = Context(1)

            test = TestMsg(x=0., y=0., z=0.)
            test_sub = Hg.ZmqSubscriber(ctx, test_sub_ip, test_sub_port)
            Hg.add_subscriber!(pubNodeIO, test, test_sub)

            debug = debug

            return new(pubNodeIO, rate, should_finish,
                       test,
                       debug)
        end
    end

    function Hg.compute(node::SubNode)
        @info node.test.x
    end



    # Launch IMU publisher
    function main(; rate=100.0, debug=false)
        test_ip = "127.0.0.1"
        test_port = "5556"

        pub_node = PubNode(test_ip, test_port,
                           rate, debug)

        sub_node = SubNode(test_ip, test_port,
                           rate, debug)

        return (pub_node, sub_node)
    end
end

# %%
import Mercury as Hg

Hg.Subscribers.reset_sub_count()
Hg.Publishers.reset_pub_count()
pub_node, sub_node = DummyNodes.main();

# %%
sub_node_task = @task Hg.launch(sub_node)
schedule(sub_node_task)

# %%
pub_node_task = @task Hg.launch(pub_node)
schedule(pub_node_task)

# %%
Hg.closeall(pub_node)
Hg.closeall(sub_node)

# %%
if all([isopen(submsg.sub) for submsg in node.nodeio.subs])
    Hg.launch(node)
else
    Hg.closeall(node)
end

# %%
Hg.closeall(node)
