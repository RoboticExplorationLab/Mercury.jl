import Dates: now, format
import Serialization: serialize

# Global Logger for easier use
# const LOGGER = MercuryLogger(ctx=ZMQ.Context(1), rate=100)

mutable struct MercuryLogger <: Hg.Node
    # Required by Abstract Node type
    nodeio::Hg.NodeIO
    log_file_name::String
    # Vector{MercuryMessage}
end

function MercuryLogger(ctx::ZMQ.Context, rate::Float64, )
    # Adding the Ground Vicon Subscriber to the Node
    loggerIO = Hg.NodeIO(ctx; rate = rate)
    log_file_name = joinpath(pwd(), "mercury_log_" * Dates.format(now(), "dd/mm/yyyy_HH:MM.h5"))
    return MercuryLogger( loggerIO, log_file_name, )
end

function Hg.setupIO!(node::MotorSpinNode, nodeio::Hg.NodeIO)
    setup_dict = TOML.tryparsefile("$(@__DIR__)/../setup.toml")

    motor_serial_ipaddr = setup_dict["zmq"]["jetson"]["motors_relay"]["in"]["server"]
    motor_serial_port = setup_dict["zmq"]["jetson"]["motors_relay"]["in"]["port"]
    motors_sub_endpoint = Hg.tcpstring(motors_serial_ipaddr, motors_serial_port)

    motor_pub = Hg.ZmqPublisher(nodeio.ctx, motor_serial_ipaddr, motor_serial_port;
                                name="MOTOR_PUB")
    Hg.add_publisher!(nodeio, node.motor_c_buf, motor_pub)

    motors_serial_device = setup_dict["serial"]["jetson"]["motors_arduino"]["serial_port"]
    # motors_serial_device = "/dev/tty.usbmodem14201"
    motors_baud_rate = setup_dict["serial"]["jetson"]["motors_arduino"]["baud_rate"]

    motors_serial_ipaddr = setup_dict["zmq"]["jetson"]["motors_relay"]["out"]["server"]
    motors_serial_port = setup_dict["zmq"]["jetson"]["motors_relay"]["out"]["port"]
    motors_pub_endpoint = Hg.tcpstring(motors_serial_ipaddr, motors_serial_port)

    node.motors_relay = Hg.launch_relay(motors_serial_device,
                                        motors_baud_rate,
                                        motors_sub_endpoint,
                                        motors_pub_endpoint,
                                        )
end

function Hg.compute(log::MercuryLogger)
    loggerIO = Hg.getIO(log)

    for sub in loggerIO.subs
        on_new(sub) do msg
            open(log.log_file_name, write=append) do io
                write(io, serialize(msg))
            end
        end
    end

    Hg.publish.(loggerIO.pubs)
end

"""
    Add a single topic to log messages from
"""
function Hg.add_log(log::MercuryLogger, ipaddr::Sockets.IPv4, port::Int64, msg::MercuryMessage; name=gensubscribername())
    tcp_port_string = tcpstring(motors_serial_ipaddr, motors_serial_port)
    sub = ZmqSubscriber(getIO(log).ctx, ipaddr, port; name=name)
    add_subscriber!(getIO(log), msg, sub)
end

function Hg.add_plot(log::MercuryLogger, ipaddr::Sockets.IPv4, port::Int64, msg::MercuryMessage; name=gensubscribername())
    tcp_port_string = tcpstring(motors_serial_ipaddr, motors_serial_port)
    sub = ZmqSubscriber(getIO(log).ctx, ipaddr, port; name=name)
    add_subscriber!(getIO(log), msg, sub)
end

function Hg.start_logging(setup_toml_filename::String, )

end

function Hg.stop_logging(log::MercuryLogger, )

    close(node.motors_relay)
end
