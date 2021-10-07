using CMake
builddir = joinpath(@__DIR__, "build")
if !isdir(builddir)
    Base.Filesystem.mkdir(builddir)
end
mercurylib_dir = joinpath(@__DIR__, "src")
config_cmd = `$cmake -S$mercurylib_dir -B$builddir`
build_cmd = `$cmake --build $builddir`
run(config_cmd)
run(build_cmd)

# Generate protobuf message files
using ProtoBuf
protodir = joinpath(@__DIR__, "..", "src", "proto")
msgfile = joinpath(protodir, "node_info.proto")
if !isfile(splitext(msgfile)[1] * "_pb.jl")
    ProtoBuf.protoc(`-I=$protodir --julia_out=$protodir $msgfile`)
end
