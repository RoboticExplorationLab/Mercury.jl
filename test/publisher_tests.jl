import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools
using LibSerialPort
if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end

# Construction
@testset "ZmqPublisher" begin
    Hg.reset_pub_count()
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port = 5555

    @testset "Zmq Pub Construction" begin
        pub = Hg.ZmqPublisher(ctx, addr, port)

        @test pub.port == port
        @test pub.ipaddr == addr
        @test Hg.portstring(pub) == "tcp://$addr:$port"
        @test pub.name == "publisher_1"
        @test Hg.getname(pub) == "publisher_1"
        @test isopen(pub)

        @test_throws ZMQ.StateError Hg.ZmqPublisher(ctx, addr, port)
        @test isopen(pub)
        close(pub)
        @test !isopen(pub.socket)

        pub2 = Hg.ZmqPublisher(ctx, addr, string(port))
        @test pub2.name == "publisher_3"
        Hg.forceclose(pub2)
        @test !isopen(pub.socket)

        pub3 = Hg.ZmqPublisher(ctx, string(addr), port, name = "mypub")
        @test pub3.name == "mypub"
        @test pub3.port == port
        close(pub3)
    end

    # Make sure the garbage collector never runs when publishing
    @testset "Pub performance" begin
        pub = Hg.ZmqPublisher(ctx, addr, port + 1)
        msg = TestMsg(x = 10, y = 11, z = 12)
        b = @benchmark Hg.publish($pub, $msg)
        @test maximum(b.gctimes) == 0.0
        close(pub)
    end

    @testset "Incomplete Pub" begin
        struct MyPub <: Hg.Publisher end
        mypub = MyPub()
        msg = TestMsg(x = 10, y = 11, z = 12)
        @test_throws Hg.MercuryException Hg.publish(mypub, msg)
    end

    @testset "Published Message" begin
        pub = Hg.ZmqPublisher(ctx, addr, port + 1)
        msg = TestMsg(x = 10, y = 11, z = 12)
        pubmsg = Hg.PublishedMessage(msg, pub, name = "TestPub")
        @test Hg.getname(pubmsg) == "TestPub"
        close(pub)
    end
end
