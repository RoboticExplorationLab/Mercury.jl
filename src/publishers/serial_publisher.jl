const MSG_BLOCK_SIZE = 256
# SLIP encodings
const END = 0xC0
const ESC = 0xDB
const ESC_END = 0xDC
const ESC_ESC = 0xDD

"""
    SerialPublisher

Write data over a serial port.
"""
mutable struct SerialPublisher <: Publisher
    serial_port::LibSerialPort.SerialPort

    name::String

    # Buffer for encoded messages
    msg_out_buffer::StaticArrays.MVector{MSG_BLOCK_SIZE,UInt8}
    msg_out_length::Int64

    function SerialPublisher(
        serial_port::LibSerialPort.SerialPort;
        name = genpublishername(),
    )
        port_name = LibSerialPort.Lib.sp_get_port_name(serial_port.ref)
        sp_name = "Serial Port-$(LibSerialPort.Lib.sp_get_port_name(serial_port.ref))"
        @catchserial(
            LibSerialPort.open(serial_port),
            "Failed to open SerialPort at serial_port $port_name"
        )

        # Vector written to when encoding Protobuf using COBS protocol
        msg_out_buffer = StaticArrays.@MVector zeros(UInt8, MSG_BLOCK_SIZE)
        msg_out_length = 0

        @info "Publishing $name on: $sp_name"
        new(serial_port, name, msg_out_buffer, msg_out_length)
    end
end

"""
    SerialPublisher(port_name::String, baudrate::Integer; [name])

Create a publisher attached to the serial port at `port_name` with a communicate rate of
`baudrate`. Automatically tries to open the port.
"""
function SerialPublisher(port_name::String, baudrate::Integer; name = genpublishername())
    local sp
    @catchserial(
        begin
            sp = LibSerialPort.open(port_name, baudrate)
            LibSerialPort.close(sp)
        end,
        "Failed to open Serial Port at $port_name"
    )

    return SerialPublisher(sp; name = name)
end


Base.isopen(pub::SerialPublisher) = LibSerialPort.isopen(pub.serial_port)
function Base.close(pub::SerialPublisher)
    @info "Closing SerialPublisher: $(getname(pub)) on: $(portstring(pub))"
    LibSerialPort.close(pub.serial_port)
end


function Base.open(pub::SerialPublisher)
    if !isopen(pub)
        LibSerialPort.open(pub.serial_port)
    end

    return Base.isopen(pub)
end

"""
    encodeSLIP(pub::SerialPublisher, payload::AbstractVector{UInt8})
Zero Allocation SLIP encoding of a message block
"""
function encodeSLIP(pub::SerialPublisher, payload::AbstractVector{UInt8})
    n = length(payload)
    pub.msg_out_length = n + 2

    pub.msg_out_buffer[1] = END
    for i in 1:n
        pub.msg_out_buffer[i+1] = payload[i]
    end
    pub.msg_out_buffer[n+2] = END

    replace!(pub.msg_out_buffer[2:n+1], ESC=>(ESC + ESC_ESC))
    replace!(pub.msg_out_buffer[2:n+1], END=>(ESC + ESC_END))

    return @view pub.msg_out_buffer[1:n+2]
end

function encode!(pub::SerialPublisher, payload::ProtoBuf.ProtoType)
    iob = IOBuffer()
    msg_size = ProtoBuf.writeproto(iob, proto_msg)
    msg = @view iob.data[1:msg_size]
    encoded_msg = encodeCOBS(pub, msg)
end

function encode!(pub::SerialPublisher, payload::AbstractVector{UInt8})
    length(payload) <= length(pub.msg_out_buffer)-2 || throw(MercuryException("Can only send messages of size $(MSG_BLOCK_SIZE-2)"))
    for i = 1:length(payload)
        pub.msg_out_buffer[i] = payload[i]
    end
    pub.msg_out_length = length(payload)
end

function publish(pub::SerialPublisher, msg)
    if isopen(pub)
        length(msg) == 0 && throw(MercuryException("Empty message passed to encode!"))
        length(msg) > 254 &&
            throw(MercuryException("Can only safely encode 254 bytes at a time"))
        encode!(pub, msg)
        write(pub.serial_port, @view pub.msg_out_buffer[1:pub.msg_out_length])
    end
    return nothing
end

portstring(sub::SerialPublisher) =
    "Serial Port-" * LibSerialPort.Lib.sp_get_port_name(sub.serial_port.ref)
