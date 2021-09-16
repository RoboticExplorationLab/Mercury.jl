msg_block_size = 256
serial_port_buffer_size = 1024

mutable struct SerialSubscriber <: Subscriber
    serial_port::LibSerialPort.SerialPort

    name::String

    read_buffer::StaticArrays.MVector{serial_port_buffer_size, UInt8}

    msg_in_buffer::StaticArrays.MVector{msg_block_size, UInt8}
    msg_in_length::Int64

    function SerialSubscriber(serial_port::LibSerialPort.SerialPort;
                            name = gensubscribername(),
                            )
        @catchserial(LibSerialPort.open(serial_port),
                    "Failed to connect to serial port: `$serial_port`"
                    )
        close(serial_port)

        # Buffer for dumping read bytes into
        read_buffer = StaticArrays.@MVector zeros(UInt8, serial_port_buffer_size)

        # Vector written to when encoding Protobuf using COBS protocol
        msg_in_buffer = StaticArrays.@MVector zeros(UInt8, msg_block_size)
        msg_in_length = 0

        new(serial_port, name, read_buffer, msg_in_buffer, msg_in_length)
    end
end

function SerialSubscriber(port_name::String,
                          baudrate::Int64;
                          name = gensubscribername(),
                          )
    sp = LibSerialPort.open(port_name, baudrate)
    LibSerialPort.close(sp)

    return SerialSubscriber(sp; name = name)
end


Base.isopen(sub::SerialSubscriber) = LibSerialPort.isopen(sub.serial_port)
Base.close(sub::SerialSubscriber) = LibSerialPort.close(sub.serial_port)

function Base.open(sub::SerialSubscriber)
    if !isopen(sub)
        LibSerialPort.open(sub.serial_port)
    end

    return Base.isopen(sub)
end


"""
    Base.readuntil(ard::Arduino, delim::UInt8)
Reads byte by byte from arduinos serial port stream and copies into
read buffer until 0x00 flag bit is encountered. Returns view into
read buffer if found complete message and nothing otherwise.
"""
function Base.readuntil(sub::SerialSubscriber, delim::UInt8)
    if isopen(sub) && (bytesavailable(sub.serial_port) > 0)
        for i in 1:length(sub.read_buffer)
            # Read one byte from LibSerialPort.SerialPort buffer into publishers
            # local buffer one byte at a time until delim byte encoutered then return
            sub.read_buffer[i] = read(sub.serial_port, UInt8)
            if sub.read_buffer[i] == delim #0x00
                return @view sub.read_buffer[max(1,i+1-msg_block_size):i]
            end
        end
    end
    # If serial port isn't open or flag byte isn't encountered in buffer return nothing
    return nothing
end

"""
    decode(msg)
Uses [COBS](https://en.wikipedia.org/wiki/Consistent_Overhead_Byte_Stuffing)
to decode message block.
"""
function decode(sub::SerialSubscriber, msg::AbstractVector{UInt8})
    incoming_msg_size = length(msg)
    incoming_msg_size == 0 && error("Empty message passed to encode!")
    incoming_msg_size > msg_block_size && error("Can only safely encode 256 bytes at a time")

    if !any(msg .== 0x00)
        return nothing
    end

    push_ind, pop_ind = 1, 1
    n = msg[pop_ind]
    pop_ind += 1

    c = 0
    b = msg[pop_ind]
    pop_ind += 1

    # While we haven't encountered flag byte and haven't read more than the
    # maximum message size
    while b ≠ 0x00 && push_ind <= msg_block_size && pop_ind <= incoming_msg_size
        c += 1
        if c < n
            sub.msg_in_buffer[push_ind] = b
        else
            sub.msg_in_buffer[push_ind] = 0x00

            n = b
            c = 0
        end

        b = msg[pop_ind]
        pop_ind += 1
        push_ind += 1
    end

    sub.msg_in_length = push_ind - 1

    return view(sub.msg_in_buffer, 1:sub.msg_in_length)
end

"""
Returns `true` if successfully read message from serial port
"""
function receive(sub::SerialSubscriber,
                 proto_msg::ProtoBuf.ProtoType,
                 write_lock = ReentrantLock(),
                 )
    if isopen(sub)
        encoded_msg = readuntil(sub, 0x00)

        if encoded_msg !== nothing
            decoded_msg = decode(sub, encoded_msg)
            lock(write_lock) do
                ProtoBuf.readproto(IOBuffer(decoded_msg), proto_msg)
            end
            return true
        end

        return false
    else
        @warn "Attempting to receive a message on subscriber $(sub.name), which is closed"
    end
end

"""
Loops recieve(sub::Subscriber, proto_msg::ProtoBuf.ProtoType, write_lock=ReentrantLock())
"""
function subscribe(sub::SerialSubscriber,
                   proto_msg::ProtoBuf.ProtoType,
                   write_lock = ReentrantLock(),
                   )
    @info "Listening for message type: $(typeof(proto_msg)), on: $(sub.name)"
    try
        while true
            receive(sub, proto_msg, write_lock)

            GC.gc(false)
        end
    catch e
        close(sub)
        @info "Shutting Down $(typeof(proto_msg)) subscriber, on: $(sub.name)"

        rethrow(e)
    end

    return nothing
end
