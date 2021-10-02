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
            if Hg.receive(sub, msg, ReentrantLock())
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
        msg = TestMsg(x = 10, y = 11, z = 12)
        msg_out = TestMsg(x = 1, y = 2, z = 3)

        # Close the task by waiting for a receive
        sub_task = @task Hg.subscribe(sub, msg, ReentrantLock())
        schedule(sub_task)
        cnt = 0
        timeout = 5.0 # seconds
        @test Hg.publish_until_receive(pub, sub, msg_out, timeout)
        @test !istaskdone(sub_task)
        # sleep(1.0)
        @show sub.flags.hasreceived
        @test msg.x == msg_out.x

        # Should be able to close at any time
        close(sub)
        sleep(0.1)  # wait a little bit to allow for the lock to be acquired
        @test !isopen(sub)
        @test isopen(pub)
        close(pub)
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
    #     sub = Hg.ZmqSubscriber(ctx, addr, port, name = "TestSub")
    #     pub = Hg.ZmqPublisher(ctx, addr, port, name = "TestPub")
    #     msg = TestMsg(x = 10, y = 11, z = 12)
    #     msg_out = TestMsg(x = 1, y = 2, z = 3)

    #     # Close the task by waiting for a receive
    #     sub_task = @task Hg.subscribe(sub, msg, ReentrantLock())
    #     schedule(sub_task)
    #     cnt = 0
    #     timeout = 5.0 # seconds
    #     @test Hg.publish_until_receive(pub, sub, msg_out, timeout)
    #     @test !istaskdone(sub_task)
    #     # sleep(1.0)
    #     @show sub.flags.hasreceived
    #     @test msg.x == msg_out.x
    #     close_task = @async close(sub)
    #     @test !istaskdone(close_task)  # waiting for receive to finish
    #     @test isopen(sub)
    #     @test isopen(pub)
    #     @test sub.flags.isreceiving
    #     @test islocked(sub.socket_lock)

    #     sub.flags.hasreceived = false
    #     Hg.publish_until_receive(pub, sub, msg_out)
    #     @test sub.flags.hasreceived
    #     sleep(0.1)
    #     @test istaskdone(close_task)  # should be closed now that the receive finished
    #     @test !isopen(sub)
    #     sleep(0.1)  # sleep to wait for socket to close and the subscribe loop to exit
    #     @test istaskdone(sub_task)  # the subscriber task should finish after the socket is closed
    #     @test !istaskfailed(sub_task)  # The task shouldn't end with an error
    #     close(pub)

    #     sub = Hg.ZmqSubscriber(ctx, addr, port)
    #     pub = Hg.ZmqPublisher(ctx, addr, port, name = "TestPub")
    #     sub_task = @task Hg.subscribe(sub, msg, ReentrantLock())
    #     schedule(sub_task)
    #     Hg.publish_until_receive(pub, sub, msg_out)
    #     !istaskdone(sub_task)
    #     Hg.forceclose(sub)
    #     sleep(0.1)  # wait for the task to finish
    #     @test istaskdone(sub_task)  # the subscriber task should finish after the socket is closed
    #     @test !istaskfailed(sub_task) # the EOFError should be caught
    #     @test !isopen(sub)
    #     @test isopen(pub)
    #     close(pub)
    #     @test !isopen(pub)
    # end

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
        sleep(.5)
        Hg.receive(sub, msg)
        second_rec = msg.x
        @test second_rec > first_rec + 10

        do_publish = false
        sleep(0.1)
        @test istaskdone(pub_task)
        close(pub)
        close(sub)
    end
end

Hg.reset_sub_count()
ctx = ZMQ.context()
addr = ip"127.0.0.1"
port = 5555

function pub_message(pub)
    msg_out = TestMsg(x = 1, y = 2, z = 3)
    global do_publish
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
do_publish = Threads.Atomic{Bool}(true) 
pub_task = @async pub_message(pub)
istaskdone(pub_task)
istaskfailed(pub_task)
do_publish[] = false 
isopen(pub)

isopen(sub)
lock = ReentrantLock()
Hg.receive(sub, msg, lock) 
msg.x
b = @benchmark Hg.receive($sub, $msg, $lock) 
@test maximum(b.gctimes) == 0
sub_task = @async Hg.subscribe(sub, msg, ReentrantLock())
istaskdone(sub_task)
istaskfailed(sub_task)

close(sub)
close(pub)

