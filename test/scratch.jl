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
println("hello")
# %%