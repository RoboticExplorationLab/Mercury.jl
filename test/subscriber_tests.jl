import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools

@testset "ZmqSubscriber" begin
    Hg.reset_sub_count()
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port = 5555

    @testset "Construction" begin
        sub = Hg.ZmqSubscriber(ctx, addr, port)

        @test isopen(sub)
        @test sub.port == port
        @test sub.ipaddr == addr
        @test sub.name == "subscriber_1"
        close(sub)
        @test !isopen(sub.socket)

        sub = Hg.ZmqSubscriber(ctx, addr, string(port))
        @test sub.port == port
        @test sub.ipaddr == addr
        @test sub.name == "subscriber_2"
        close(sub)

        sub = Hg.ZmqSubscriber(ctx, string(addr), port)
        @test sub.port == port
        @test sub.ipaddr == addr
        @test sub.name == "subscriber_3"
        close(sub)

        # Create 2 subscribers
        @test_nowarn begin
            sub1 = Hg.ZmqSubscriber(ctx, string(addr), port)
            sub2 = Hg.ZmqSubscriber(ctx, string(addr), port)
            close(sub1)
            close(sub2)
        end
    end

    @testset "Simple Pub/Sub" begin
        # Test simple pub/sub
        sub = Hg.ZmqSubscriber(ctx, addr, port)
        @test isopen(sub)
        msg = TestMsg(x = 10, y = 11, z = 12)
        rtask = @task Hg.receive(sub, msg)
        schedule(rtask)
        istaskdone(rtask)

        pub = Hg.ZmqPublisher(ctx, addr, port)
        msg_out = TestMsg(x = 1, y = 2, z = 3)
        @test msg.x == 10
        @test msg.y == 11
        @test msg.z == 12
        Hg.publish(pub, msg_out)
        sleep(0.1)
        @test istaskdone(rtask)
        @test msg.x == 1
        @test msg.y == 2
        @test msg.z == 3
        close(pub)
        close(sub)
    end


    @testset "Receive performance" begin
        ## Test receive performance
        function pub_message(pub)
            msg_out = TestMsg(x = 1, y = 2, z = 3)
            global do_publish
            i = 0
            while (do_publish)
                msg_out.x = i
                Hg.publish(pub, msg_out)
                i += 1
                sleep(0.001)
            end
        end
        sub = Hg.ZmqSubscriber(ctx, addr, port, name = "TestSub")
        pub = Hg.ZmqPublisher(ctx, addr, port, name = "TestPub")
        msg = TestMsg(x = 10, y = 11, z = 12)

        # Publish message in a separate task (really fast)
        global do_publish = true
        pub_task = @task pub_message(pub)
        schedule(pub_task)
        @test !istaskdone(pub_task)

        # Make sure it doesn't have any garbage collection time
        b = @benchmark Hg.receive($sub, $msg)
        @test maximum(b.gctimes) == 0
        do_publish = false
        sleep(0.1)
        @test istaskdone(pub_task)
        close(pub)
        close(sub)

        # Check that receive doesn't error after closing the port
        # but should print a warning message
        @test_logs (:warn, r"Attempting to receive.*TestSub.*which is closed") Hg.receive(
            sub,
            msg,
        )
    end
end
