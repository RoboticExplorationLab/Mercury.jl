import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools

include("jlout/test_msg_pb.jl")

Hg.reset_pub_count()
ctx = ZMQ.Context()
addr = ip"127.0.0.1"
port = 5555

sub = Hg.Subscriber(ctx, addr, port, name = "TestSub")
pub = Hg.Publisher(ctx, addr, port, name = "TestPub")
msg = TestMsg(x = 10, y = 11, z = 12)

# %%
function pub_message(pub)
    msg_out = TestMsg(x = 1, y = 2, z = 3)
    i = 0
    while (true)
        msg_out.x = i
        Hg.publish(pub, msg_out)
        i += 1
        sleep(0.01)
    end
end

# %%
pub_task = @task pub_message(pub)
schedule(pub_task)
@test !istaskdone(pub_task)

# %%
Hg.receive(sub, msg)
msg.x

# %%
if !istaskdone(pub_task)
    Base.throwto(pub_task, InterruptException())
end
istaskdone(pub_task)


# %%
function sub_message(sub)
    rate = 10  # Subscribing at 10 Hz
    lrl = Hg.LoopRateLimiter(rate)

    msg = TestMsg(x = 1, y = 2, z = 3)
    i=0
    Hg.@rate while true
        msg.x = i
        Hg.receive(sub, msg)
        i += 1
    end lrl
end
# %%
while(!istaskdone(pub_task))
    sleep(0.001)
end

# %%
# global do_publish = true
pub_task = @task pub_message(pub)
schedule(pub_task)
@test !istaskdone(pub_task)

# %%
close(pub)
close(sub)

# %%
while (true)
    Hg.receive(sub, msg)
    print(msg.x,"\r")
end

# %%
global do_publish = false

#  %%
@test istaskdone(pub_task)


# %%






# %%
import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools

include("jlout/test_msg_pb.jl")

@testset "Pub/Sub Performance" begin
    Hg.reset_sub_count()
    Hg.reset_pub_count()
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port = 5555

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

        sub = Hg.Subscriber(ctx, addr, port, name = "TestSub")
        pub = Hg.Publisher(ctx, addr, port, name = "TestPub")
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
        println(second_rec, " ", first_rec)

        do_publish = false
        sleep(0.1)
        @test istaskdone(pub_task)
        close(pub)
        close(sub)
    end
end