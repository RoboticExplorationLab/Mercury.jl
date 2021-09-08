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