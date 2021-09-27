const MSG_BLOCK_SIZE = 256
const SERIAL_PORT_BUFFER_SIZE = 1024

mutable struct SerialSubscriber <: Subscriber
    serial_port::LibSerialPort.SerialPort

    name::String

    read_buffer::StaticArrays.MVector{SERIAL_PORT_BUFFER_SIZE, UInt8}

    msg_in_buffer::StaticArrays.MVector{MSG_BLOCK_SIZE, UInt8}
    msg_in_length::Int64

    flags::SubscriberFlags

    function SerialSubscriber(serial_port::LibSerialPort.SerialPort;
                              name = gensubscribername(),
                              )
        @catchserial(LibSerialPort.open(serial_port),
                    "Failed to connect to serial port: `$serial_port`"
                    )
        LibSerialPort.close(serial_port)

        # Buffer for dumping read bytes into
        read_buffer = StaticArrays.@MVector zeros(UInt8, SERIAL_PORT_BUFFER_SIZE)

        # Vector written to when encoding Protobuf using COBS protocol
        msg_in_buffer = StaticArrays.@MVector zeros(UInt8, MSG_BLOCK_SIZE)
        msg_in_length = 0

        @info "Subscribing $name on serial port"
        new(
            serial_port,
            name,
            read_buffer,
            msg_in_buffer,
            msg_in_length,
            SubscriberFlags(),
            )
    end
end

function SerialSubscriber(port_name::String,
                          baudrate::Int64;
                          name = gensubscribername(),
                          )
    local sp
    @catchserial(
        begin
            sp = LibSerialPort.open(port_name, baudrate)
            LibSerialPort.close(sp)
        end,
        "Failed to connect to serial port at: `$port_name`"
        )

    return SerialSubscriber(sp; name = name)
end


Base.isopen(sub::SerialSubscriber) = LibSerialPort.isopen(sub.serial_port)
Base.close(sub::SerialSubscriber) = LibSerialPort.close(sub.serial_port)


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
                return @view sub.read_buffer[max(1,i+1-MSG_BLOCK_SIZE):i]
            end
        end
    end
    # If serial port isn't open or flag byte isn't encountered in buffer return nothing
    return @view UInt8[][:]
end

"""
    decode(msg)
Uses [COBS](https://en.wikipedia.org/wiki/Consistent_Overhead_Byte_Stuffing)
to decode message block.
"""
function decode(sub::SerialSubscriber, msg::AbstractVector{UInt8})
    incoming_msg_size = length(msg)
    incoming_msg_size == 0 && error("Empty message passed to encode!")
    incoming_msg_size > MSG_BLOCK_SIZE && error("Can only safely encode 256 bytes at a time")

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
    while b ≠ 0x00 && push_ind <= MSG_BLOCK_SIZE && pop_ind <= incoming_msg_size
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
                 write_lock::ReentrantLock,
                 )
    if isopen(sub)
        sub.flags.isreceiving = true
        encoded_msg = readuntil(sub, 0x00)
        sub.flags.isreceiving = false

        if !isempty(encoded_msg)
            decoded_msg = decode(sub, encoded_msg)
            lock(write_lock) do
                ProtoBuf.readproto(IOBuffer(decoded_msg), proto_msg)
            end

            sub.flags.hasreceived = true
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
                   write_lock::ReentrantLock,
                   )
    @info "$(sub.name): Listening for message type: $(typeof(proto_msg)), on: $(sub.name)"
    try
        while isopen(sub)
            receive(sub, proto_msg, write_lock)
            GC.gc(false)
            yield()
        end
        @info "Shutting Down subscriber $(getname(sub)) on: $(tcpstring(sub)). Socket was closed."
    catch err
        sub.flags.diderror = true
        close(sub)
        @warn "Shutting Down $(typeof(proto_msg)) subscriber, on: $(sub.name)"
        @error err exception=(err, catch_backtrace())
    end

    return nothing
end

