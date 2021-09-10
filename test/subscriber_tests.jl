import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools
if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end


@testset "Subscriber" begin
    Hg.reset_sub_count()
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port = 5555

    @testset "Construction" begin
        sub = Hg.Subscriber(ctx, addr, port)

        @test isopen(sub)
        @test sub.port == port
        @test sub.ipaddr == addr
        @test sub.name == "subscriber_1"
        close(sub)
        @test !isopen(sub.socket)

        sub = Hg.Subscriber(ctx, addr, string(port))
        @test sub.port == port
        @test sub.ipaddr == addr
        @test sub.name == "subscriber_2"
        close(sub)

        sub = Hg.Subscriber(ctx, string(addr), port)
        @test sub.port == port
        @test sub.ipaddr == addr
        @test sub.name == "subscriber_3"
        close(sub)

        # Create 2 subscribers
        @test_nowarn begin
            sub1 = Hg.Subscriber(ctx, string(addr), port)
            sub2 = Hg.Subscriber(ctx, string(addr), port)
            close(sub1)
            close(sub2)
        end
    end

    @testset "Simple Pub/Sub" begin
        Hg.reset_sub_count()
        Hg.reset_pub_count()

        # Test simple pub/sub
        sub = Hg.Subscriber(ctx, addr, port)
        @test isopen(sub)
        msg = TestMsg(x = 10, y = 11, z = 12)
        rtask = @task Hg.receive(sub, msg)
        schedule(rtask)
        istaskdone(rtask)

        pub = Hg.Publisher(ctx, addr, port)
        msg_out = TestMsg(x = 1, y = 2, z = 3)
        @test msg.x == 10
        @test msg.y == 11
        @test msg.z == 12
        cnt = 0
        for i = 1:1000
            msg_out.x = i
            Hg.publish(pub, msg_out)
            sleep(0.001)
            if istaskdone(rtask) 
                cnt = i 
                break
            end
        end
        @test sub.flags.hasreceived
        @test istaskdone(rtask)
        @test msg.x == cnt   # The first many are "lost." It accepts the first one to be received.
        @test msg.y == 2
        @test msg.z == 3
        close(pub)
        close(sub)
    end


    # @testset "Receive performance" begin
    #     ## Test receive performance
    #     function pub_message(pub)
    #         msg_out = TestMsg(x = 1, y = 2, z = 3)
    #         global do_publish
    #         i = 0
    #         while (do_publish)
    #             msg_out.x = i
    #             Hg.publish(pub, msg_out)
    #             i += 1
    #             sleep(0.001)
    #         end
    #     end
    #     sub = Hg.Subscriber(ctx, addr, port, name = "TestSub")
    #     pub = Hg.Publisher(ctx, addr, port, name = "TestPub")
    #     msg = TestMsg(x = 10, y = 11, z = 12)

    #     # Publish message in a separate task (really fast)
    #     global do_publish = true
    #     pub_task = @task pub_message(pub)
    #     schedule(pub_task)
    #     @test !istaskdone(pub_task)

    #     # Make sure it doesn't have any garbage collection time
    #     b = @benchmark Hg.receive($sub, $msg)
    #     @test maximum(b.gctimes) == 0
    #     do_publish = false
    #     sleep(0.1)
    #     @test istaskdone(pub_task)
    #     close(pub)
    #     close(sub)
    # end

    @testset "Subscriber close" begin
        msg = TestMsg(x = 10, y = 11, z = 12)
        msg_out = TestMsg(x = 1, y = 2, z = 3)
        sub = Hg.Subscriber(ctx, addr, port)
        pub = Hg.Publisher(ctx, addr, port, name = "TestPub")

        # Close the task by waiting for a receive
        sub_task = @task Hg.subscribe(sub, msg)
        schedule(sub_task)
        cnt = 0
        Hg.publish_until_receive(pub, sub, msg_out)
        @test !istaskdone(sub_task)
        sleep(0.5)
        @show sub.flags.hasreceived
        @test msg.x == msg_out.x
        close_task = @async close(sub)
        @test !istaskdone(close_task)  # waiting for receive to finish

        sub.flags.hasreceived = false
        Hg.publish_until_receive(pub, sub, msg_out)
        @test istaskdone(close_task)  # should be closed now that the receive finished 
        @test !isopen(sub)
        sleep(0.1)  # sleep to wait for socket to close and the subscribe loop to exit
        @test istaskdone(sub_task)  # the subscriber task should finish after the socket is closed
        @test !istaskfailed(sub_task)  # The task shouldn't end with an error
        close(pub)

        sub = Hg.Subscriber(ctx, addr, port)
        pub = Hg.Publisher(ctx, addr, port, name = "TestPub")
        sub_task = @task Hg.subscribe(sub, msg)
        schedule(sub_task)
        Hg.publish_until_receive(pub, sub, msg_out)
        !istaskdone(sub_task)
        Hg.forceclose(sub)
        sleep(0.1)  # wait for the task to finish
        @test istaskdone(sub_task)  # the subscriber task should finish after the socket is closed
        @test istaskfailed(sub_task) # the task will exit with an error since 
        close(pub)
    end

end
