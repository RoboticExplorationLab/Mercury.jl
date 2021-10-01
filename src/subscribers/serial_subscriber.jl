const SERIAL_PORT_BUFFER_SIZE = 1024
const MSG_BLOCK_SIZE = 256

mutable struct SerialSubscriber <: Subscriber
    serial_port::LibSerialPort.SerialPort
    name::String

    # Flags denoting start and end of message
    # header_flag::UInt32
    # footer_flag::UInt32

    # read_buffer::StaticArrays.MVector{SERIAL_PORT_BUFFER_SIZE,UInt8}
    msg_in_buffer::StaticArrays.MVector{MSG_BLOCK_SIZE,UInt8}
    msg_in_length::Int64

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
        msg_in_buffer = StaticArrays.@MVector zeros(UInt8, MSG_BLOCK_SIZE)
        msg_in_length = 0

        @info "Subscribing $name on serial port: `$(LibSerialPort.Lib.sp_get_port_name(serial_port.ref))`"
        new(
            serial_port,
            name,
            msg_in_buffer,
            msg_in_length,
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


Base.isopen(sub::SerialSubscriber) = LibSerialPort.isopen(sub.serial_port)
function Base.close(sub::SerialSubscriber)
    @info "Closing SerialSubscriber: $(getname(sub))"
    LibSerialPort.close(sub.serial_port)
end
forceclose(sub::SerialSubscriber) = close(sub)


function Base.readuntil(sub::SerialSubscriber, delim::UInt8)
    if isopen(sub) && (bytesavailable(sub.serial_port) > 0)
        for i = 1:length(sub.read_buffer)
            # Read one byte from LibSerialPort.SerialPort buffer into publishers
            # local buffer one byte at a time until delim byte encoutered then return
            sub.read_buffer[i] = read(sub.serial_port, UInt8)
            if sub.read_buffer[i] == delim #0x00
                return @view sub.read_buffer[max(1, i + 1 - MSG_BLOCK_SIZE):i]
            end
        end
    end
    # return nothing
    # If serial port isn't open or flag byte isn't encountered in buffer return nothing
    return @view UInt8[][:]
end


"""
    read_packet(sub::SerialSubscriber)
"""
function read_packet(sub::SerialSubscriber, delim::UInt8)
    if isopen(sub) && (bytesavailable(sub.serial_port) > 0)
        header_window = reinterpret(UInt8, [sub.header_flag])
        footer_window = reinterpret(UInt8, [sub.footer_flag])

        window = zeros()

        while(bytesavailable(sub.serial_port))
            read(sub.serial_port, UInt8)
        end

        for i = 1:length(sub.read_buffer)
            # Read one byte from LibSerialPort.SerialPort buffer into publishers
            # local buffer one byte at a time until delim byte encoutered then return
            sub.read_buffer[i] = read(sub.serial_port, UInt8)
            if sub.read_buffer[i] == delim #0x00
                return @view sub.read_buffer[max(1, i + 1 - MSG_BLOCK_SIZE):i]
            end
        end
    end
    # return nothing
    # If serial port isn't open or flag byte isn't encountered in buffer return nothing
    return @view UInt8[][:]
end

function Base.occursin(needle::AbstractVector{UInt8}, haystack::AbstractVector{UInt8})
    ned_len = length(needle)
    hay_len = length(haystack)
    ned_len <= hay_len || throw(MercuryException("needle must be shorter or of equal length to haystack"))

    n = hay_len - ned_len + 1
    for i in 1:n
        if all(needle .== haystack[i:i+ned_len-1])
            return true
        end
    end
    return false
end

function is_valid_packet(msg::AbstractVector{UInt8})
    temp = msg[2:end-1]

    head_foot = (msg[1] == msg[end] == END)
    contains_end = (END in temp)
    constains_esc_esc_end= occursin(SA[ESC, ESC_END], temp)
    constains_esc_esc_end= occursin(SA[ESC, ESC_END], temp)


    return !((END in temp) || (temp[end] == ESC) ||
             (((ESC + ESC_END) in temp) || ((ESC + ESC_ESC) in temp)))
end


"""
    decodeSLIP(msg)
Uses [SLIP](https://en.wikipedia.org/wiki/Serial_Line_Internet_Protocol)
to decode message block.
"""
function decodeSLIP(sub::SerialSubscriber, msg::AbstractVector{UInt8})
    is_valid_packet(msg) || throw(MercuryException("Trying to decode non-valid SLIP packet!"))

    n = length(msg)
    sub.msg_in_length = n - 2

    for i in 1:n-2
        sub.msg_in_buffer[i] = msg[i+1]
    end

    replace!(sub.msg_in_buffer, (ESC + ESC_END)=>END)
    replace!(sub.msg_in_buffer, (ESC + ESC_ESC)=>ESC)

    return @view sub.msg_in_buffer[1:n-2]
end

"""
Returns `true` if successfully read message from serial port
"""
function receive(
    sub::SerialSubscriber,
    buf,
    write_lock::ReentrantLock,
)
    if isopen(sub)
        sub.flags.isreceiving = true
        encoded_msg = readuntil(sub, 0x00)
        sub.flags.isreceiving = false

        if !isempty(encoded_msg)
            bin_data = decode_packet(sub, encoded_msg)

            lock(write_lock) do
                sub.flags.bytesrecieved = decode!(buf, bin_data)
            end

            sub.flags.hasreceived = true
            return true
        end

        return false
    else
        @warn "Attempting to receive a message on subscriber $(sub.name), which is closed"
    end
end


portstring(sub::SerialSubscriber) =
    "Serial Port-" * LibSerialPort.Lib.sp_get_port_name(sub.serial_port.ref)

