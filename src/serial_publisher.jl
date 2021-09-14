empty_message_str = "Empty message passed to encode!"
big_message_str = "Can only safely encode 254 bytes at a time"

msg_block_size = 256

"""
"""
mutable struct SerialPublisher
    serial_port::LibSerialPort.SerialPort

    name::String

    proto_buffer::IOBuffer

    # Buffer for encoded messages
    msg_out_buffer::StaticArrays.MVector{msg_block_size, UInt8}
    msg_out_length::Int64

    function SerialPublisher(serial_port::LibSerialPort.SerialPort;
                             name = genpublishername(),
                             )
        @catchserial(LibSerialPort.open(serial_port),
                        "Failed to open serial port: `$serial_port`"
                        )
        close(serial_port)

        # Buffer for writing ProtoBuf messages
        proto_buffer = IOBuffer()
        # Vector written to when encoding Protobuf using COBS protocol
        msg_out_buffer = StaticArrays.@MVector zeros(UInt8, msg_block_size)
        msg_out_length = 0

        new(serial_port, name, proto_buffer, msg_out_buffer, msg_out_length)
    end
end

function SerialPublisher(port_name::String,
                         baudrate::Int64;
                         name = genpublishername(),
                         )
    sp = LibSerialPort.open(port_name, baudrate)
    LibSerialPort.close(sp)

    return SerialPublisher(sp; name = name)
end


Base.isopen(pub::SerialPublisher) = LibSerialPort.isopen(pub.serial_port)
Base.close(pub::SerialPublisher) = LibSerialPort.close(pub.serial_port)

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
function encode(pub::SerialPublisher, payload::AbstractVector{UInt8})
    length(payload) == 0 && error("empty_message_str")
    length(payload) > 254 && error("big_message_str")

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
    reverse!(pub.msg_out_buffer, 1, pub.msg_out_length-1)
    # Add on end flag to message
    pub.msg_out_buffer[pub.msg_out_length] = 0x00
    # Return a view into the msg buffer of just critical part of the buffer
    return view(pub.msg_out_buffer, 1:pub.msg_out_length)
end


function publish(pub::SerialPublisher, proto_msg::ProtoBuf.ProtoType)
    if isopen(pub)
        # Serialize the protobuf message
        iob = IOBuffer()
        msg_size = ProtoBuf.writeproto(iob, proto_msg)
        msg = @view iob.data[1:msg_size]
        # Encode the serialized message using COBS
        encoded_msg = encode(pub, msg)
        write(pub.serial_port, encoded_msg)

        # Move to the beginning of the buffer used for writing protobufs
        # seek(pub.proto_buffer, 0)
    end
end
