using ZMQ


# Set conflate option for ZMQ, not included in ZMQ.jl
# function set_conflate(socket::ZMQ.Socket, option_val::Integer)
#     rc = ccall((:zmq_setsockopt, ZMQ.libzmq), Cint,
#             (Ptr{Cvoid}, Cint, Ref{Cint}, Ref{Csize_t}),
#             socket, 54, option_val, sizeof(Cint))
#     if rc != 0
#         println(Base.Libc.errno())
#         throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
#     end
# end

# Set conflate option for ZMQ, not included in ZMQ.jl
function get_conflate(socket::ZMQ.Socket, option_val::Integer)
    rc = ccall((:zmq_getsockopt, ZMQ.libzmq), Cint,
            (Ptr{Cvoid}, Cint, Ref{Cint}, Ref{Csize_t}),
            socket, 54, option_val, sizeof(Cint))
    if rc != 0
        println(Base.Libc.errno())
        throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
    end
end

# Set conflate option for ZMQ, not included in ZMQ.jl
function set_conflate(socket::ZMQ.Socket, option_val::Integer)
    Cint_size = sizeof(Cint)

    rc = ccall((:zmq_setsockopt, ZMQ.libzmq), Cint,
            (Ptr{Cvoid}, Cint, Ref{Cint}, Csize_t),
            socket, 54, option_val, Cint_size)
    if rc != 0
        println(Base.Libc.errno())
        throw(ZMQ.StateError(ZMQ.jl_zmq_error_str()))
    end
end


# %%
ctx = ZMQ.Context(1)
sock = ZMQ.Socket(ctx, ZMQ.SUB)
ZMQ.subscribe(sock)
sock

# %%
rc = set_conflate(sock, 1)

# %%
get_conflate(sock, true)

# %%
close(ctx)

# %%
close(sock)


# set_conflate(sock, 1)



# %%
isopen(sock)
close(sock)



# %%
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

# %%
test1 = rand(UInt8, 16)
test2 = test1[5:9]
occursin(test2, test1)

# %%
test1 = rand(UInt8, 16)
test2 = test1[12:16]
occursin(test2, test1)

# %%
test1 = rand(UInt8, 16)
test2 = rand(UInt8, 17)
occursin(test2, test1)

# %%

struct MOTORS_C
    front_left::Cfloat;
    front_right::Cfloat;
    back_right::Cfloat;
    back_left::Cfloat;

    time::Cdouble;
end

# %%
using BenchmarkTools


function test(mot::Vector{MOTORS_C})
    mot[1] = MOTORS_C(rand(Float32), rand(Float32), rand(Float32), rand(Float32), rand(Float64))
end

# %%
mot = [MOTORS_C(rand(Float32), rand(Float32), rand(Float32), rand(Float32), rand(Float64))]
@btime test($mot)