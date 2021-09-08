import Mercury as Hg
import ProtoBuf
using Test

outdir = joinpath(@__DIR__, "jlout")
protodir = joinpath(@__DIR__, "proto")
msgfile = joinpath(protodir, "test_msg.proto")
ProtoBuf.protoc(`-I=$protodir --julia_out=$outdir $msgfile`)

include("publisher_tests.jl")