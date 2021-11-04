# Interface
const SerialZmqRelay = Base.Process

struct SerialRelayError <: Exception
    msg::String
end

SERIAL_PORTS = Dict{String,SerialZmqRelay}()

function launch_relay(
    port_name::String,
    baudrate::Int64,
    sub_endpoint::String,
    pub_endpoint::String,
)::SerialZmqRelay

    if port_name in keys(SERIAL_PORTS) && process_running(SERIAL_PORTS[port_name])
        @info "Serial port: $(port_name), already has associate ZMQ relay running!"
        return SERIAL_PORTS[port_name]
    end

    @info "Launching serial relay for: $(port_name), with write port: $(sub_endpoint) and read port: $(pub_endpoint)"
    relay_exe = joinpath(dirname(pathof(Mercury)), "..", "deps", "build", "relay_launch")
    cmd = `$relay_exe $port_name $baudrate $sub_endpoint $pub_endpoint`

    err = Pipe()
    serial_relay = run(pipeline(cmd, stderr = err), wait = false)
    close(err.in)
    sleep(1.0) # Wait for c constructor in relay_launch to either run successfully or fail

    if !process_running(serial_relay)
        err_msg = String(read(err))
        throw(SerialRelayError(err_msg))
    end

    SERIAL_PORTS[port_name] = serial_relay
    return serial_relay
end

function check_relays()
    if port_name in keys(SERIAL_PORTS)
        if !process_running(SERIAL_PORTS[port_name])
            @warn "Serial-ZMQ relay running on serialport: $port_name has stopped running!"
            delete!(SERIAL_PORTS, port_name)
        end
    end
end

function Base.close(serial_relay::SerialZmqRelay)
    if process_running(serial_relay) # true
        @info "Closing down Serial-ZMQ relay."
        kill(serial_relay)
    end
end

# TODO: Check if there is a way to capture STDOUT/STDERR from process without waiting
function check_relay_running(serial_relay::SerialZmqRelay)
    if !process_running(serial_relay) # true
        @warn "Serial-ZMQ relay shut down!."
        throw(ProcessFailedException)
    end
end

function closeall_relays()
    for port_name in keys(SERIAL_PORTS)
        @info "Closing down Serial-ZMQ relay running on serialport: $port_name"

        close(SERIAL_PORTS[port_name])
        delete!(SERIAL_PORTS, port_name)
    end
end

# Make sure all processes are cleaned up
Base.atexit(closeall_relays)
