var documenterSearchIndex = {"docs":
[{"location":"api.html#API","page":"API","title":"API","text":"","category":"section"},{"location":"api.html","page":"API","title":"API","text":"This page is a dump of all the docstrings found in the code. This will be cleaned up in the future and organized to be more accessible.","category":"page"},{"location":"api.html","page":"API","title":"API","text":"Modules = [Mercury]\nOrder = [:module, :type, :function, :macro]","category":"page"},{"location":"api.html#Mercury.LoopRateLimiter","page":"API","title":"Mercury.LoopRateLimiter","text":"LoopRateLimiter\n\nRuns a loop at a fixed rate. Works best for loops where the runtime is approximately the same every iteration. The loop runtime is kept approximately constant by sleeping  for any time not used by the core computation. This is useful for situations where  the computation should take place a regular, predictable intervals.\n\nTo achieve better accuracy, the rate limiter records the error between the expected  runtime and actual runtime every N_batch iterations, and adjusts the sleep time  by the average. Unlike the standard sleep function in Julia, this limiter has a  minimum sleep time of 1 microsecond, and rates above 1000Hz can be achieved with  moderate accuracy.\n\nExample\n\nlrl = LoopRateLimiter(100)  # Hz\nreset!(lrl)\nfor i = 1:100\n    startloop(lrl)          # start timing the loop\n    myexpensivefunction()   # execute the core body of the loop\n    sleep(lrl)              # sleep for the rest of the time\nend\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.Publisher","page":"API","title":"Mercury.Publisher","text":"Publisher\n\nA simple wrapper around a ZMQ publisher, but only publishes protobuf messages.\n\nConstruction\n\nPublisher(context::ZMQ.Context, ipaddr, port; name)\n\nTo create a publisher, pass in a ZMQ.Context, which allows all related  publisher / subscribers to be collected in a \"group.\" The publisher also  needs to be provided the IPv4 address (either as a string or as a Sockets.IPv4 object), and the port (either as an integer or a string).\n\nA name can also be optionally provided via the name keyword, which can be used to provide a helpful description about what the publisher is publishing. It defaults to \"publisher_#\" where # is an increasing index.\n\nIf the port \n\nUsage\n\nTo publish a message, just use the publish method on a protobuf type:\n\npublish(pub::Publisher, proto_msg::ProtoBuf.ProtoType)\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.Subscriber","page":"API","title":"Mercury.Subscriber","text":"Subscriber\n\nA simple wrapper around a ZMQ subscriber, but only for protobuf messages.\n\nConstruction\n\nSubscriber(context::ZMQ.Context, ipaddr, port; name)\n\nTo create a subscriber, pass in a ZMQ.Context, which allows all related  publisher / subscribers to be collected in a \"group.\" The subscriber also  needs to be provided the IPv4 address (either as a string or as a Sockets.IPv4 object), and the port (either as an integer or a string).\n\nA name can also be optionally provided via the name keyword, which can be used to provide a helpful description about what the subscriber is subscribing to. It defaults to \"subscriber_#\" where # is an increasing index.\n\nUsage\n\nUse the blocking subscribe method to continually listen to the socket and  store data in a protobuf type:\n\nsubscribe(sub::Subscriber, proto_msg::ProtoBuf.ProtoType)\n\nNote that this function contains an infinite while loop so will block the calling thread indefinately. It's usually best to assign the process to a separate thread / task:\n\nsub_task = @task subscribe(sub, proto_msg)\nschedule(sub_task)\n\n\n\n\n\n","category":"type"},{"location":"api.html#Base.sleep-Tuple{Mercury.LoopRateLimiter}","page":"API","title":"Base.sleep","text":"sleep(::LoopRateLimiter)\n\nSleep the OS for the amount of time needed to achieve the rate specified by the loop rate  limiter. Has a minimum sleep time of 1 microsecond (relies on the usleep C function).\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.reset!-Tuple{Mercury.LoopRateLimiter}","page":"API","title":"Mercury.reset!","text":"reset!(::LoopRateLimiter)\n\nReset the loop rate limiter before a loop. Not necessary if the object is created directly before calling the loop.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.startloop-Tuple{Mercury.LoopRateLimiter}","page":"API","title":"Mercury.startloop","text":"startloop(::LoopRateLimiter)\n\nCall this function at the beginning of a loop body to start timing the loop.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.usleep-Tuple{Any}","page":"API","title":"Mercury.usleep","text":"usleep(us)\n\nSleep for us microseconds. A wrapper around the C usleep function in unistd.h.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.@rate-Tuple{Any, Any}","page":"API","title":"Mercury.@rate","text":"@rate\n\nRun a loop at a fixed rate, specified either by an integer literal or a  LoopRateLimiter object. It will run the loop so that it executes close  to rate iterations per second.\n\nExamples\n\n@rate for i = 1:100\n    myexpensivefunction()\nend 200#Hz\n\nlr = LoopRateLimiter(200, N_batch=10)\n@rate while i < 100\n    myexpensivefunction()\n    i += 1\nend lr\n\nNote that the following does NOT work:\n\nrate = 100\n@rate for i = 1:100\n    myexpensivefunction()\nend rate \n\nSince Julia macros dispatch on the compile-time types instead of the run-time types.\n\n\n\n\n\n","category":"macro"},{"location":"index.html#Mercury","page":"Introduction","title":"Mercury","text":"","category":"section"},{"location":"index.html#Overview","page":"Introduction","title":"Overview","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"Mercury.jl is a light-weight message passing system for robotics applications built  on top of ZMQ.jl and ProtoBuf.jl. It's main goal is to provide a fast and efficient  method for setting up autonomy stacks on embedded systems or microcomputers. ","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"This project is still in early development by the Robotic Exploration Lab at Carnegie Mellon University. The package will be registered  as an official Julia package as soon as we get it working reliably on real hardware.","category":"page"}]
}
