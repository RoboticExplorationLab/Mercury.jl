import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools

# Construction
@testset "ZmqPublisher" begin
    Hg.reset_pub_count()
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port = 5555

    @testset "Zmq Pub Construction" begin
        pub = Hg.ZmqPublisher(ctx, addr, port)

        pub.port == port
        pub.ipaddr == addr
        Hg.tcpstring(pub) == "tcp://$addr:$port"
        pub.name == "publisher_1"
        isopen(pub)

        @test_throws ZMQ.StateError Hg.ZmqPublisher(ctx, addr, port)
        @test isopen(pub)
        close(pub)
        @test !isopen(pub.socket)

        pub2 = Hg.ZmqPublisher(ctx, addr, string(port))
        @test pub2.name == "publisher_3"
        close(pub2)

        pub3 = Hg.ZmqPublisher(ctx, string(addr), port, name = "mypub")
        @test pub3.name == "mypub"
        @test pub3.port == port
        close(pub3)
    end

    # Make sure the garbage collector never runs when publishing
    @testset "Pub performance" begin
        pub = Hg.ZmqPublisher(ctx, addr, port)
        msg = TestMsg(x = 10, y = 11, z = 12)
        b = @benchmark Hg.publish($pub, $msg)
        @test maximum(b.gctimes) == 0.0
        close(pub)
    end
end
