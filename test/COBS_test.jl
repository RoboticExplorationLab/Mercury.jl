import Mercury as Hg
using ZMQ
using Sockets
using Test
using BenchmarkTools

include("jlout/test_msg_pb.jl")

Hg.reset_sub_count()
Hg.reset_pub_count()
port_name = "/dev/tty.usbmodem14201"
baudrate = 57600
sub = Hg.SerialSubscriber(port_name, baudrate);
pub = Hg.SerialPublisher(port_name, baudrate);
test_msg = TestMsg(x=1,y=2,z=3)


# %% Benchmarking
open(pub)
try
    @btime for i in 1:100
        Hg.publish(pub, test_msg)
        sleep(0.001)
    end
finally
    close(pub)
end


# %% COBS Test Set
@testset "COBS" begin

    test_data = rand(UInt8, 150);
    test_data[test_data .== 0x00] .= 0x01
    too_big_test_data = rand(UInt8, 600)

    # Check encode and decode are inverses of one another
    code_decode_results = Hg.decode(sub, Hg.encode(pub, test_data))
    @test code_decode_results == test_data
    # Check that decoding a vector without any 0x00 byte fails
    @test Hg.decode(sub, test_data) === nothing
    # Check that the encode fails if messages are too big
    @test begin
        try
            Hg.encode(pub, too_big_test_data)
        catch e
            e isa ErrorException ? true : false
        end
    end
    too_big_test_data[too_big_test_data .== 0x00] .= 0x01
    # Check that the decode fails if messages are too big
    @test begin
        try
            Hg.decode(sub, too_big_test_data)
        catch e
            e isa ErrorException ? true : false
        end
    end
end
