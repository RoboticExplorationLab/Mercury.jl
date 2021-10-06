const SERIAL_PORT_BUFFER_SIZE = 1024
const MSG_BLOCK_SIZE = 256

mutable struct SerialSubscriber <: Subscriber
    serial_port::LibSerialPort.SerialPort
    name::String

    read_buffer::StaticArrays.MVector{SERIAL_PORT_BUFFER_SIZE,UInt8}
    msg_in_buffer::StaticArrays.MVector{MSG_BLOCK_SIZE,UInt8}
    msg_in_length::Int64

    buffer::IOBuffer

    flags::SubscriberFlags

    function SerialSubscriber(
        serial_port::LibSerialPort.SerialPort;
        name = gensubscribername(),
    )
        @catchserial(
            LibSerialPort.open(serial_port),
            "Failed to connect to serial port: `$(LibSerialPort.Lib.sp_get_port_name(serial_port.ref))`"
        )

        # Buffer for dumping read bytes into
        read_buffer = StaticArrays.@MVector zeros(UInt8, SERIAL_PORT_BUFFER_SIZE)
        msg_in_buffer = StaticArrays.@MVector zeros(UInt8, MSG_BLOCK_SIZE)
        msg_in_length = 0

        buffer = IOBuffer(zeros(UInt8, MSG_BLOCK_SIZE))

        @info "Subscribing $name on serial port: `$(LibSerialPort.Lib.sp_get_port_name(serial_port.ref))`"
        new(
            serial_port,
            name,
            read_buffer,
            msg_in_buffer,
            msg_in_length,
            buffer,
            SubscriberFlags(),
        )
    end
end

function SerialSubscriber(
    port_name::String,
    baudrate::Int64;
    name = gensubscribername()
    )
    local sp
    @catchserial(
        begin
            sp = LibSerialPort.open(port_name, baudrate)
            LibSerialPort.close(sp)
        end,
        "Failed to connect to serial port at: `$port_name`"
    )
    return SerialSubscriber(sp; name=name)
end

getcomtype(::SerialSubscriber) = :serial

Base.isopen(sub::SerialSubscriber) = LibSerialPort.isopen(sub.serial_port)
function Base.close(sub::SerialSubscriber)
    @info "Closing SerialSubscriber: $(getname(sub))"
    LibSerialPort.close(sub.serial_port)
end
forceclose(sub::SerialSubscriber) = close(sub)

function read_packet(sub::SerialSubscriber)
    delim = 0x00
    if isopen(sub) && (bytesavailable(sub.serial_port) > 0)
        while (bytesavailable(sub.serial_port) > 0)
            if read(sub.serial_port, UInt8) == delim
                break # Encountered end of previous packet
            end
        end

        for i = 1:length(sub.read_buffer)
            # Read one byte from LibSerialPort.SerialPort buffer into publishers
            # local buffer one byte at a time until delim byte encoutered then return
            sub.read_buffer[i] = read(sub.serial_port, UInt8)
            if sub.read_buffer[i] == delim
                return @view sub.read_buffer[max(1, i + 1 - MSG_BLOCK_SIZE):i]
            end
        end
    end
    # If serial port isn't open or flag byte isn't encountered return empty view
    return @view UInt8[][:]
end

"""
    decodeCOBS(msg)
Uses [COBS](https://en.wikipedia.org/wiki/Consistent_Overhead_Byte_Stuffing)
to decode message block.
"""
function decodeCOBS(sub::SerialSubscriber, msg::AbstractVector{UInt8})
    incoming_msg_size = length(msg)
    incoming_msg_size == 0 && error("Empty message passed to encode!")
    incoming_msg_size > MSG_BLOCK_SIZE &&
        error("Can only safely encode 256 bytes at a time")

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
function receive(
    sub::SerialSubscriber,
    buf,
    write_lock::ReentrantLock,
)
    did_receive = false
    sub.flags.isreceiving = true
    bytes_read = 0

    if isopen(sub)
        encoded_msg = read_packet(sub)
        sub.flags.isreceiving = false

        if !isempty(encoded_msg)
            bin_data = decodeCOBS(sub, encoded_msg)
            bytes_read = length(bin_data)
            sub.flags.bytesrecieved = bytes_read

            sub.flags.hasreceived = true
            did_receive = true
        end
    end

    if bytes_read > length(sub.buffer.data)
        @warn "Increasing buffer size for subscriber $(getname(sub)) from $(length(sub.buffer.data)) to $bytes_read."
        sub.buffer.data = zeros(UInt8, bytes_read)
        sub.buffer.size = bytes_read
    end

    # Copy the data to the local buffer and decode
    if did_receive
        seek(sub.buffer, 0)
        sub.buffer.size = bytes_read
        for i = 1:bytes_read
            sub.buffer.data[i] = bin_data[i]
        end

        lock(write_lock)
            decode!(buf, sub.buffer)
        unlock(write_lock)
    end

    return did_receive
end

portstring(sub::SerialSubscriber) =
    "Serial Port-" * LibSerialPort.Lib.sp_get_port_name(sub.serial_port.ref)

