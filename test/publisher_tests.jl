import Mercury as Hg
using ZMQ
using Sockets
using Test
include("jlout/test_msg_pb.jl")

# Construction
Hg.reset_pub_count()
ctx = ZMQ.Context(1)
addr = ip"127.0.0.1"
port = 5555
pub = Hg.Publisher(ctx, addr, port)

pub.port == port
pub.ipaddr == addr
Hg.tcpstring(pub) == "tcp://$addr:$port"
pub.name == "publisher_1"
isopen(pub)

@test_throws ZMQ.StateError Hg.Publisher(ctx, addr, port)
isopen(pub)
close(pub)
!isopen(pub.socket)

pub2 = Hg.Publisher(ctx, addr, string(port))
pub2.name == "publisher_3"
close(pub2)

pub3 = Hg.Publisher(ctx, string(addr), port, name="mypub")
pub3.name == "mypub"
pub3.port == port

# Make sure the garbage collector never runs when publishing
msg = TestMsg(x=10, y=11, z=12)
b = @benchmark Hg.publish($pub3, $msg)
@test maximum(b.gctimes) == 0.0