module Mercury
import ZMQ
import Sockets
import ProtoBuf
import Logging

const libhg = joinpath(@__DIR__, "..", "deps", "build", "libhg.so")


greet() = print("Hello World!")
include("utils.jl")
include("publisher.jl")
include("subscriber.jl")

end # module
