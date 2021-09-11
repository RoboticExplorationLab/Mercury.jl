module Mercury
import ZMQ
import Sockets
import ProtoBuf
import Logging
import StaticArrays
import LibSerialPort

const libhg = joinpath(@__DIR__, "..", "deps", "build", "libhg.so")


greet() = print("Hello World!")
include("utils.jl")
include("publisher.jl")
include("subscriber.jl")
include("serial_publisher.jl")
include("serial_subscriber.jl")

end # module
