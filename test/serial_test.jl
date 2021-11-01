import Mercury as Hg
import ZMQ
using Sockets
using Test

# @testset "Serial Relay Tests" begin
    serial_port_name = "/dev/tty.usbmodem14201"
    baudrate = 57600
    ctx = ZMQ.Context()
    addr = ip"127.0.0.1"
    port_in = "5555"
    port_out = "5556"

    bytes_out = Vector{UInt8}("Hello World!")
    bytes_in = zeros(UInt8, 256)

    # serial_relay = Hg.launch_relay(serial_port_name,
    #                                baudrate,
    #                                Hg.tcpstring(addr, port_in),
    #                                Hg.tcpstring(addr, port_out),
    #                                )

    # do_publish = Threads.Atomic{Bool}(true)

    # function pub_message(pub)
    #     bytes_out = Vector{UInt8}("Hello World!")
    #     do_publish
    #     while (do_publish[])
    #         Hg.publish(pub, bytes_out)
    #         sleep(0.1)
    #     end
    # end

    pub = Hg.ZmqPublisher(ctx, addr, port_in, name = "TestPub")
    # for i in 1:10
    #     Hg.publish(pub, bytes_out)
    #     sleep(1)
    # end


    # sub = Hg.ZmqSubscriber(ctx, addr, port_out, name = "TestSub")

    # pub_task = @async pub_message(pub)


    # @test Hg.receive(sub, bytes_in)
    # display(String(bytes_in))
    # sleep(1.0)
    # @test Hg.receive(sub, bytes_in)
    # display(String(bytes_in))


    # do_publish[] = false
    # wait(pub_task)
    # close(sub)
    # close(pub)
    # close(serial_relay)
# end
