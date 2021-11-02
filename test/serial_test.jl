import Mercury as Hg
import ZMQ
using Sockets
using Test

if !isdefined(@__MODULE__, :TestMsg)
    include("jlout/test_msg_pb.jl")
end


# @testset "Serial Relay Tests" begin
    serial_port_name = "/dev/tty.usbmodem14201"
    baudrate = 57600
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port_in = "5555"
    port_out = "5556"

    # serial_relay = Hg.launch_relay(serial_port_name,
    #                                baudrate,
    #                                Hg.tcpstring(addr, port_in),
    #                                Hg.tcpstring(addr, port_out),
    #                                )

    do_publish = Threads.Atomic{Bool}(true)
    function pub_message(pub, msg)
        do_publish
        while (do_publish[])
            Hg.publish(pub, msg)
            sleep(0.5)
        end
    end

    pub = Hg.ZmqPublisher(ctx, addr, port_in, name = "TestPub")
    # msg_out = TestMsg(x = 10, y = 11, z = 12)
    msg_out = Vector{UInt8}("Hello World!")
    pub_task = @async pub_message(pub, msg_out)
    sleep(1.0)

    # Subscriber to subscribe directly to pub
    sub1 = Hg.ZmqSubscriber(ctx, addr, port_in, name = "TestSub")
    # Subscriber to subscribe directly to the serial_relay pub.
    # These should produce identical results
    sub2 = Hg.ZmqSubscriber(ctx, addr, port_out, name = "TestSub")

    # Recieve pure bytes
    bytes_in1 = zeros(UInt8, 256)
    bytes_in2 = zeros(UInt8, 256)

    while true
        recieved1 = Hg.receive(sub1, bytes_in1)
        recieved2 = Hg.receive(sub2, bytes_in2)
        if recieved1
            println("Sub1: ", String(bytes_in1[1:27]))
        end
        if recieved2
            println("Sub2: ", String(bytes_in2[1:27]))
        end
        sleep(0.1)
    end

    # recieved1 = false
    # for i in 1:100
    #     recieved1 = Hg.receive(sub1, bytes_in1)
    #     sleep(0.1)
    # end
    # recieved2 = false
    # for i in 1:100
    #     recieved2 = Hg.receive(sub2, bytes_in2)
    #     sleep(0.1)
    # end
    # @test recieved1
    # @test recieved2

    # @test all(bytes_in1 .== bytes_in2)

    # msg_in1 = TestMsg(x = 1, y = 1, z = 1)
    # msg_in2 = TestMsg(x = 1, y = 1, z = 1)

    # @test Hg.receive(sub1, msg_in1)
    # @test Hg.receive(sub2, msg_in2)

    # @test msg_out.x == msg_in1.x == msg_in2.x
    # @test msg_out.y == msg_in1.y == msg_in2.y
    # @test msg_out.z == msg_in1.z == msg_in2.z

    # do_publish[] = false
    # wait(pub_task)
    # close(sub1)
    # close(sub2)
    # close(pub)
    # close(serial_relay)
# end
