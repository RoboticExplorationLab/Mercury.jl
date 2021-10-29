import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools
if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end
ENV["JULIA_DEBUG"] = "Mercury"

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

        pub = Hg.ZmqPublisher(ctx, addr, port)
        msg_out = TestMsg(x = 1, y = 2, z = 3)
        @test msg.x == 10
        @test msg.y == 11
        @test msg.z == 12
        sleep(0.2)  # needed to give time to set up publisher?

        # publish and receive a message
        @test !sub.flags.hasreceived
        i = 1
        for i = 1:100
            Hg.publish(pub, msg_out)
            if Hg.receive(sub, msg)
                break
            end
        end
        @test i < 100
        @test sub.flags.hasreceived

        # make sure the correct message was received
        @test msg.x == 1
        @test msg.y == 2
        @test msg.z == 3
        close(pub)
        close(sub)
    end

    @testset "Closing" begin
        sub = Hg.ZmqSubscriber(ctx, addr, port, name = "TestSub")
        pub = Hg.ZmqPublisher(ctx, addr, port, name = "TestPub")
        msg_in = TestMsg(x = 10, y = 11, z = 12)
        msg_out = TestMsg(x = 1, y = 2, z = 3)

        # Close the task by waiting for a receive
        cnt = 0
        timeout = 5.0 # seconds
        @test Hg.publish_until_receive(pub, sub, msg_out, msg_in, timeout)
        @test msg_in.x == msg_out.x

        # Should be able to close at any time
        close(sub)
        sleep(0.1)  # wait a little bit to allow for the lock to be acquired
        @test !isopen(sub)
        @test isopen(pub)
        close(pub)
    end

    @testset "Subscribe performance" begin
        do_publish = Threads.Atomic{Bool}(true)

        function pub_message(pub)
            msg_out = TestMsg(x = 1, y = 2, z = 3)
            do_publish
            i = 0
            while (do_publish[])
                msg_out.x = i
                Hg.publish(pub, msg_out)
                i += 1
                sleep(0.001)
            end
        end

        sub = Hg.ZmqSubscriber(ctx, addr, port)
        msg = TestMsg(x = 0, y = 0, z = 0)

        pub = Hg.ZmqPublisher(ctx, addr, port, name = "TestPub")
        msg_out = TestMsg(x = 10, y = 11, z = 12)
        pub_task = @async pub_message(pub)
        @test !istaskdone(pub_task)
        @test !istaskfailed(pub_task)
        # do_publish[] = false
        @test isopen(pub)

        @test isopen(sub)

        # Retrieve 2 messages to make sure the publisher is working
        Hg.receive(sub, msg)
        x_prev = msg.x
        sleep(1.0)
        Hg.receive(sub, msg)
        x_new = msg.x
        @test x_new - x_prev > 100

        # Benchmark the receive
        b = @benchmark Hg.receive($sub, $msg)
        @test maximum(b.gctimes) == 0  # no garbage collection
        @test b.memory == 0            # no dynamic memory allocations

        # Close task and sockets
        do_publish[] = false
        wait(pub_task)
        close(sub)
        close(pub)
    end

    @testset "Testing Subscriber Conflate" begin
        ## Test receive performance
        function pub_message(pub)
            rate = 100  # Publishing at 100 Hz
            lrl = Hg.LoopRateLimiter(rate)

            msg_out = TestMsg(x = 1, y = 2, z = 3)
            global do_publish
            i = 0
            Hg.@rate while (do_publish)
                msg_out.x = i
                Hg.publish(pub, msg_out)
                i += 1
                sleep(0.001)
            end lrl
        end

        sub = Hg.ZmqSubscriber(ctx, addr, port, name = "TestSub")
        pub = Hg.ZmqPublisher(ctx, addr, port, name = "TestPub")
        msg = TestMsg(x = 10, y = 11, z = 12)

        # Publish message in a separate task (really fast)
        global do_publish = true
        pub_task = @task pub_message(pub)
        schedule(pub_task)
        @test !istaskdone(pub_task)

        Hg.receive(sub, msg)
        first_rec = msg.x
        sleep(0.5)
        Hg.receive(sub, msg)
        second_rec = msg.x
        @test second_rec > first_rec + 5

        do_publish = false
        sleep(0.1)
        @test istaskdone(pub_task)
        close(pub)
        close(sub)
    end

end

@testset "Published/Subscribed ZMQ Messages" begin
    Hg.reset_sub_count()
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port = 5555

    sub = Hg.ZmqSubscriber(ctx, addr, port, name = "TestSub")
    pub = Hg.ZmqPublisher(ctx, addr, port, name = "TestPub")
    msg = TestMsg(x = 10, y = 11, z = 12)
    msg_out = TestMsg(x = 1, y = 2, z = 3)

    submsg = Hg.SubscribedMessage(msg, sub)
    pubmsg = Hg.PublishedMessage(msg_out, pub)

    @test !Hg.getflags(submsg.sub).hasreceived
    while (!Hg.getflags(submsg.sub).hasreceived)
        Hg.publish(pubmsg)
        sleep(0.001)
        Hg.receive(submsg)
    end
    @test Hg.getflags(submsg.sub).hasreceived
    @test isopen(sub)
    @test isopen(pub)
    Hg.forceclose(sub)
    close(pub)
    sleep(0.2)  # give a little bit of time to close the task
end
