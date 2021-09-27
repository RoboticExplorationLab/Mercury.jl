module Mercury

import ZMQ
import Sockets
import ProtoBuf
import Logging
import StaticArrays
import LibSerialPort

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

# include("publishers/publishers.jl")
# using .Publishers
# include("publishers/pub_utils.jl")
include("publishers/abstract_publisher.jl")
include("publishers/serial_publisher.jl")
include("publishers/zmq_publisher.jl")

# include("subscribers/subscribers.jl")
# using .Subscribers
# include("subscribers/sub_utils.jl")
include("subscribers/abstract_subscriber.jl")
include("subscribers/serial_subscriber.jl")
include("subscribers/zmq_subscriber.jl")
include("subscribers/subscribed_vicon.jl")

include("node.jl")

end # module
