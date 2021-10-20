# Interface
const SerialZmqRelay = Ptr{Cvoid}

mutable struct SerialRelay
    relay::SerialZmqRelay
    port_name::String

    write_ip_port::String
    read_ip_port::String

    open::Bool
end

struct SerialRelayError <: Exception
    msg::String
end

SERIAL_PORTS = Dict{String, SerialRelay}()

Base.isopen(serial_relay::SerialRelay) = serial_relay.open

function Base.close(serial_relay::SerialRelay)
    if isopen(serial_relay)
        @info "Closing Serial-ZMQ relay on port: $(serial_relay.port_name)."
        # ccall((:stop_relay, libhg),
        #       Cvoid,
        #       (SerialZmqRelay, ),
        #       serial_relay.relay)

        ccall((:close_relay, libhg),
              Cvoid,
              (SerialZmqRelay, ),
              serial_relay.relay)
    end
    serial_relay.open = false

    return
end

function open_relay(port_name,
                    baudrate,
                    sub_endpoint,
                    pub_endpoint)::SerialRelay
    relay = C_NULL
    local err_msg

    mktemp() do path, io
        # Capture the stderr
        redirect_stderr(io) do
            relay = ccall((:open_relay, libhg),
                          SerialZmqRelay,
                          (Cstring, Cint, Cstring, Cstring),
                          port_name, baudrate, sub_endpoint, pub_endpoint
                          )
        end
        # Write std_err msg to err_msg variable
        flush(io)
        err_msg = read(path, String)
    end

    if relay == C_NULL
        @error SerialRelayError(err_msg)
    end

    return SerialRelay(relay, port_name, sub_endpoint, pub_endpoint, true)
end

function relay_launch(serial_relay::SerialRelay)
    if serial_relay.port_name in keys(SERIAL_PORTS)
        if isopen(SERIAL_PORTS[serial_relay.port_name])
            delete!(SERIAL_PORTS, serial_relay.port_name)
        else
            @info "Serial port: $(serial_relay.port_name), already has associate ZMQ relay running!"
            return
        end
    end

    proc = Threads.@spawn ccall((:relay_launch, libhg),
                                Cvoid,
                                (SerialZmqRelay, ),
                                serial_relay.relay
                                )
    SERIAL_PORTS[serial_relay.port_name] = serial_relay
end
