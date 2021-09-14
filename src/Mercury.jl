module Mercury
import ZMQ
import Sockets
import ProtoBuf
import Logging

# Import correct library name for specific system
libhg_library_filename = ""
if Sys.islinux()
    libhg_library_filename = joinpath(@__DIR__, "..", "deps", "build", "libhg.so")
elseif Sys.isapple()
    libhg_library_filename = joinpath(@__DIR__, "..", "deps", "build", "libhg.dylib")
end
const libhg = libhg_library_filename


greet() = print("Hello World!")
include("utils.jl")
include("publisher.jl")
include("subscriber.jl")

end # module
