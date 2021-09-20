import Mercury as Hg
import ProtoBuf
using Sockets
using ZMQ
using BenchmarkTools
using Test

# Generate ProtoBuf julia files
outdir = joinpath(@__DIR__, "jlout")
if !isdir(outdir)
    Base.Filesystem.mkdir(outdir)
end
protodir = joinpath(@__DIR__, "proto")
msgfile = joinpath(protodir, "test_msg.proto")
ProtoBuf.protoc(`-I=$protodir --julia_out=$outdir $msgfile`)

include(joinpath(@__DIR__, "jlout","test_msg_pb.jl"))

include("publisher_tests.jl")
include("subscriber_tests.jl")
if Sys.islinux()
    include("rate_limiter_tests.jl")
end
