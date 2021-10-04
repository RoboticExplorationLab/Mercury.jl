const MSG_BLOCK_SIZE = 256

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

    flags::PublisherFlags


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
        new(serial_port, name, msg_out_buffer, msg_out_length, PublisherFlags())
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

getcomtype(::SerialPublisher) = :serial

Base.isopen(pub::SerialPublisher) = LibSerialPort.isopen(pub.serial_port)
function Base.close(pub::SerialPublisher)
    @info "Closing SerialPublisher: $(getname(pub)) on: $(portstring(pub))"
    getflags(pub).should_finish[] = true
    while isopen(pub)
        LibSerialPort.close(pub.serial_port)
    end
end

function Base.open(pub::SerialPublisher)
    if !isopen(pub)
        LibSerialPort.open(pub.serial_port)
    end

    return Base.isopen(pub)
end

"""
    encode(pub::SerialPublisher, payload::AbstractVector{UInt8})
Zero Allocation COBS encoding of a message block
"""
function encodeCOBS(pub::SerialPublisher, payload::AbstractVector{UInt8})
    n = length(payload)
    pub.msg_out_length = n + 2

    ind = 0x01
    acc = 0x01
    for x in Iterators.reverse(payload)
        if iszero(x)
            pub.msg_out_buffer[ind] = acc
            acc = 0x00
        else
            pub.msg_out_buffer[ind] = x
        end
        ind += 0x01
        acc += 0x01
    end
    pub.msg_out_buffer[pub.msg_out_length-1] = acc

    # Reverse the msg_buffer
    reverse!(pub.msg_out_buffer, 1, pub.msg_out_length - 1)
    # Add on end flag to message
    pub.msg_out_buffer[pub.msg_out_length] = 0x00
    # Return a view into the msg buffer of just critical part of the buffer
    return view(pub.msg_out_buffer, 1:pub.msg_out_length)
end

function encode!(pub::SerialPublisher, payload::ProtoBuf.ProtoType)
    iob = IOBuffer()
    msg_size = ProtoBuf.writeproto(iob, proto_msg)
    msg = @view iob.data[1:msg_size]
    encoded_msg = encodeCOBS(pub, msg)
end

function encode!(pub::SerialPublisher, payload::AbstractVector{UInt8})
    length(payload) <= length(pub.msg_out_buffer)-2 || throw(MercuryException("Can only send messages of size $(MSG_BLOCK_SIZE-2)"))
    encoded_msg = encodeCOBS(pub, payload)
end

function publish(pub::SerialPublisher, msg)
    # if getflags(pub).should_finish[]
    #     close(pub)
    # elseif isopen(pub)
    if isopen(pub)
        length(msg) == 0 && throw(MercuryException("Empty message passed to encode!"))
        length(msg) > 254 &&
            throw(MercuryException("Can only safely encode 254 bytes at a time"))
        encoded_msg = encode!(pub, msg)

        write(pub.serial_port, encoded_msg)
        getflags(pub).has_published[] = true
    end
    return nothing
end

portstring(sub::SerialPublisher) =
    "Serial Port-" * LibSerialPort.Lib.sp_get_port_name(sub.serial_port.ref)
