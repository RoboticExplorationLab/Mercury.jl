import Mercury as Hg
import ZMQ
using Sockets
using Test

if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end


@testset "Serial Relay Tests" begin
    serial_port_name = "/dev/tty.usbmodem14201"
    baudrate = 57600
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port_in = "5555"
    port_out = "5556"

    serial_relay = Hg.launch_relay(
        serial_port_name,
        baudrate,
        Hg.tcpstring(addr, port_in),
        Hg.tcpstring(addr, port_out),
    )

    do_publish = Threads.Atomic{Bool}(true)
    function pub_message(pub, msg)
        do_publish
        while (do_publish[])
            Hg.publish(pub, msg)
            sleep(0.5)
        end
    end

    pub = Hg.ZmqPublisher(ctx, addr, port_in, name = "TestPub")
    # Subscriber to subscribe directly to pub
    sub1 = Hg.ZmqSubscriber(ctx, addr, port_in, name = "TestSub")
    # Subscriber to subscribe directly to the serial_relay pub.
    # These should produce identical results
    sub2 = Hg.ZmqSubscriber(ctx, addr, port_out, name = "TestSub")

    # Test the serial relay with pure byte arrays
    do_publish[] = true
    bytes_out = Vector{UInt8}("Hello World!")
    pub_task = @async pub_message(pub, bytes_out)
    sleep(2.0)

    # Input arrays
    bytes_in1 = zeros(UInt8, sizeof(bytes_out))
    bytes_in2 = zeros(UInt8, sizeof(bytes_out))

    recieved1 = false
    recieved2 = false
    for i = 1:100
        if !recieved1
            recieved1 = Hg.receive(sub1, bytes_in1)
        elseif !recieved2
            recieved2 = Hg.receive(sub2, bytes_in2)
        else
            break
        end
        sleep(0.1)
    end
    @test recieved1
    @test recieved2
    @test all(bytes_out .== bytes_in1 .== bytes_in2)
    do_publish[] = false
    wait(pub_task)

    # Test the code with Protobuf messages
    msg_out = TestMsg(x = 10, y = 11, z = 12)
    do_publish[] = true
    pub_task = @async pub_message(pub, msg_out)
    sleep(2.0)

    msg_in1 = TestMsg(x = 1, y = 1, z = 1)
    msg_in2 = TestMsg(x = 1, y = 1, z = 1)

    recieved1 = false
    recieved2 = false
    for i = 1:100
        if !recieved1
            recieved1 = Hg.receive(sub1, msg_in1)
        elseif !recieved2
            recieved2 = Hg.receive(sub2, msg_in2)
        else
            break
        end
        sleep(0.1)
    end
    @test recieved1
    @test recieved2
    @test msg_out.x == msg_in1.x == msg_in2.x
    @test msg_out.y == msg_in1.y == msg_in2.y
    @test msg_out.z == msg_in1.z == msg_in2.z

    do_publish[] = false
    wait(pub_task)
    close(sub1)
    close(sub2)
    close(pub)
    close(serial_relay)
end
