import Mercury as Hg
using LibSerialPort
using Test
using BenchmarkTools


@testset "Serial Pub/Sub Tests" begin
    include("../jlout/test_msg_pb.jl")
    port_name = "/dev/tty.usbmodem92222901"
    baudrate = 57600

    @testset "Subscriber Construction" begin
        Hg.reset_sub_count()
        sub = Hg.SerialSubscriber(port_name, baudrate);

        @test open(sub)
        @test isopen(sub)
        @test sub.name == "subscriber_1"
        close(sub)
        @test !isopen(sub.serial_port)

        sp = LibSerialPort.open(port_name, baudrate)
        close(sp)
        sub = Hg.SerialSubscriber(sp);

        @test open(sub)
        @test isopen(sub)
        @test sub.serial_port == sp
        @test sub.name == "subscriber_2"
        close(sub)
        @test !isopen(sub.serial_port)
    end

    @testset "Publisher Construction" begin
        Hg.reset_pub_count()
        pub = Hg.SerialPublisher(port_name, baudrate);

        @test open(pub)
        @test isopen(pub)
        @test pub.name == "publisher_1"
        close(pub)
        @test !isopen(pub)
        @test !isopen(pub.serial_port)

        sp = LibSerialPort.open(port_name, baudrate)
        close(sp)
        pub = Hg.SerialPublisher(sp);

        @test open(pub)
        @test isopen(pub)
        @test pub.serial_port == sp
        @test pub.name == "publisher_2"
        close(pub)
        @test !isopen(pub)
        @test !isopen(pub.serial_port)
    end

    @testset "COBS encode/decode" begin
        Hg.reset_sub_count()
        Hg.reset_pub_count()
        sp = LibSerialPort.open(port_name, baudrate)
        close(sp)

        sub = Hg.SerialSubscriber(sp);
        pub = Hg.SerialPublisher(sp);

        test_msg = TestMsg(x=1, y=2, z=3)

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

    @testset "Simple Pub/Sub" begin
        # Test simple pub/sub on same port
        sp = LibSerialPort.open(port_name, baudrate)
        close(sp)

        sub = Hg.SerialSubscriber(sp);
        pub = Hg.SerialPublisher(sp);
        msg = TestMsg(x = 10, y = 11, z = 12)
        msg_out = TestMsg(x = 1, y = 2, z = 3)

        @test msg.x == 10
        @test msg.y == 11
        @test msg.z == 12

        open(sp)
        try
            Hg.publish(pub, msg_out)
            sleep(0.001)
            Hg.receive(sub, msg)
        finally
            close(sp)
        end

        @test msg.x == 1
        @test msg.y == 2
        @test msg.z == 3
    end

    @testset "Publish/Receive Performance" begin
        sp = LibSerialPort.open(port_name, baudrate)
        close(sp)

        sub = Hg.SerialSubscriber(sp, name = "TestSub")
        pub = Hg.SerialPublisher(sp, name = "TestPub")

        function pub_sub_circle()
            msg_out = TestMsg(x = 1, y = 2, z = 3)
            msg_in = TestMsg(x = 10, y = 11, z = 12)

            Hg.publish(pub, msg_out)
            sleep(0.05)
            Hg.receive(sub, msg_in)
        end

        open(sp)
        try
            b = @benchmark $pub_sub_circle()
            @test maximum(b.gctimes) == 0
        finally
            close(sp)
        end
    end
end