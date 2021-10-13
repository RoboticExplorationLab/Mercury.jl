import Mercury as Hg
using Test
using BenchmarkTools


@testset "Serial Pub/Sub Tests" begin
    include("jlout/test_msg_pb.jl")
    out_port_name = "/dev/tty.usbserial-D309D5SC"
    in_port_name = "/dev/tty.usbserial-D309DNQ0"
    baudrate = 57600

    # @testset "SerialSubscriber Construction" begin
    #     Hg.reset_sub_count()
    #     sub = Hg.SerialSubscriber(in_port_name, baudrate);

    #     @test isopen(sub)
    #     @test sub.name == "subscriber_1"
    #     close(sub)
    #     @test !isopen(sub.serial_port)

    #     sp = LibSerialPort.open(in_port_name, baudrate)
    #     close(sp)
    #     sub = Hg.SerialSubscriber(sp);

    #     @test isopen(sub)
    #     @test sub.serial_port == sp
    #     @test sub.name == "subscriber_2"
    #     close(sub)
    #     @test !isopen(sub.serial_port)
    # end

    # @testset "SerialPublisher Construction" begin
    #     Hg.reset_pub_count()
    #     pub = Hg.SerialPublisher(out_port_name, baudrate);

    #     @test isopen(pub)
    #     @test pub.name == "publisher_1"
    #     close(pub)
    #     @test !isopen(pub)
    #     @test !isopen(pub.serial_port)

    #     sp = LibSerialPort.open(out_port_name, baudrate)
    #     close(sp)
    #     pub = Hg.SerialPublisher(sp);

    #     @test isopen(pub)
    #     @test pub.serial_port == sp
    #     @test pub.name == "publisher_2"
    #     close(pub)
    #     @test !isopen(pub)
    #     @test !isopen(pub.serial_port)
    # end

    # @testset "COBS encode/decode" begin
    #     sub = Hg.SerialSubscriber(in_port_name, baudrate);
    #     pub = Hg.SerialPublisher(out_port_name, baudrate);

    #     test_msg = TestMsg(x=1, y=2, z=3)

    #     test_data = rand(UInt8, 150);
    #     test_data[test_data .== 0x00] .= 0x01
    #     too_big_test_data = rand(UInt8, 600)

    #     # Check encode and decode are inverses of one another
    #     code_decode_results = Hg.decode(sub, Hg.encode(pub, test_data))
    #     @test code_decode_results == test_data
    #     # Check that decoding a vector without any 0x00 byte fails
    #     @test Hg.decode(sub, test_data) === nothing
    #     # Check that the encode fails if messages are too big
    #     @test begin
    #         try
    #             Hg.encode(pub, too_big_test_data)
    #         catch e
    #             e isa ErrorException ? true : false
    #         end
    #     end
    #     too_big_test_data[too_big_test_data .== 0x00] .= 0x01
    #     # Check that the decode fails if messages are too big
    #     @test begin
    #         try
    #             Hg.decode(sub, too_big_test_data)
    #         catch e
    #             e isa ErrorException ? true : false
    #         end
    #     end

    #     close(sub)
    #     close(pub)
    # end

    @testset "Simple Serial Pub/Sub" begin
        ## Test receive performance
        function pub_message(pub)
            rate = 100  # Publishing at 100 Hz
            lrl = Hg.LoopRateLimiter(rate)

            msg_out = TestMsg(x = 1, y = 2, z = 3)
            global do_publish
            Hg.@rate while (do_publish)
                Hg.publish(pub, msg_out)
            end lrl
        end

        # Test simple pub/sub on same port
        pub = Hg.SerialPublisher(out_port_name, baudrate)
        sub = Hg.SerialSubscriber(in_port_name, baudrate)
        msg = TestMsg(x = 10, y = 11, z = 12)

        @test msg.x == 10
        @test msg.y == 11
        @test msg.z == 12

        sub_task = @async Hg.subscribe(sub, msg, ReentrantLock())

        # Publish message in a separate task (really fast)
        global do_publish = true
        pub_task = @async pub_message(pub)
        @test !istaskdone(pub_task)

        sleep(10)

        # Close the sub and pub threads
        close_sub_task = @async close(sub)
        # close_pub_task = @async close(pub)
        wait(close_sub_task)
        # wait(close_pub_task)
        global do_publish = false
        wait(pub_task)

        @test msg.x == 1
        @test msg.y == 2
        @test msg.z == 3
    end
    # @testset "Publish/Receive Performance" begin
    #     sub = Hg.SerialSubscriber(in_port_name, baudrate, name = "TestSub")
    #     pub = Hg.SerialPublisher(out_port_name, baudrate, name = "TestPub")

    #     function pub_sub_circle()
    #         msg_out = TestMsg(x = 1, y = 2, z = 3)
    #         msg_in = TestMsg(x = 10, y = 11, z = 12)

    #         Hg.publish(pub, msg_out)
    #         sleep(0.01)
    #         Hg.receive(sub, msg_in)
    #     end

    #     b = @benchmark $pub_sub_circle()
    #     @test maximum(b.gctimes) == 0

    #     close(sub)
    #     close(pub)
    # end
end

# # %%
# import Mercury as Hg
# using Test
# using BenchmarkTools

# include("jlout/test_msg_pb.jl")
# out_port_name = "/dev/tty.usbmodem14201"
# in_port_name = "/dev/tty.usbmodem14201"
# baudrate = 57600

# # %%
# sub = Hg.SerialSubscriber(in_port_name, baudrate);
# close(sub)
# pub = Hg.SerialPublisher(out_port_name, baudrate);
# close(pub)

# # %%
# test_data = rand(UInt8, 150);
# test_data[test_data .== 0x00] .= 0x01
# too_big_test_data = rand(UInt8, 600)

# # Check encode and decode are inverses of one another
# code_decode_results = Hg.decodeSLIP(sub, Hg.encodeSLIP(pub, test_data))
# @test all(code_decode_results .== test_data)
# # %%
# Hg.is_valid_packet(Hg.encodeSLIP(pub, test_data))

# # %%
# # Check that decoding a vector without any 0x00 byte fails
# @test Hg.decodeSLIP(sub, test_data) === nothing
# # Check that the encode fails if messages are too big
# @test begin
#     try
#         Hg.encode(pub, too_big_test_data)
#     catch e
#         e isa ErrorException ? true : false
#     end
# end
# too_big_test_data[too_big_test_data .== 0x00] .= 0x01
# # Check that the decode fails if messages are too big
# @test begin
#     try
#         Hg.decode(sub, too_big_test_data)
#     catch e
#         e isa ErrorException ? true : false
#     end
# end

# close(sub)
# close(pub)
# end
