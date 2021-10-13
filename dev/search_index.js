var documenterSearchIndex = {"docs":
[{"location":"api.html#API","page":"API","title":"API","text":"","category":"section"},{"location":"api.html","page":"API","title":"API","text":"This page is a dump of all the docstrings found in the code. This will be cleaned up in the future and organized to be more accessible.","category":"page"},{"location":"api.html","page":"API","title":"API","text":"Modules = [Mercury]\nOrder = [:module, :type, :function, :macro]","category":"page"},{"location":"api.html#Mercury.LoopRateLimiter","page":"API","title":"Mercury.LoopRateLimiter","text":"LoopRateLimiter\n\nRuns a loop at a fixed rate. Works best for loops where the runtime is approximately the same every iteration. The loop runtime is kept approximately constant by sleeping for any time not used by the core computation. This is useful for situations where the computation should take place a regular, predictable intervals.\n\nTo achieve better accuracy, the rate limiter records the error between the expected runtime and actual runtime every N_batch iterations, and adjusts the sleep time by the average. Unlike the standard sleep function in Julia, this limiter has a minimum sleep time of 1 microsecond, and rates above 1000Hz can be achieved with moderate accuracy.\n\nExample\n\nlrl = LoopRateLimiter(100)  # Hz\nreset!(lrl)\nfor i = 1:100\n    startloop(lrl)          # start timing the loop\n    myexpensivefunction()   # execute the core body of the loop\n    sleep(lrl)              # sleep for the rest of the time\nend\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.Node","page":"API","title":"Mercury.Node","text":"Node\n\nA independent process that communicates with other processes via pub/sub ZMQ channels. The process is assumed to run indefinately.\n\nDefining a new Node\n\nEach node should contain a NodeData element, which stores a list of the publishers and subscribers and some other associated data.\n\nThe publisher and subscribers for the node should be \"registered\" with the NodeData using the add_publisher! and add_subscriber! methods. This allows the subscribers to be automatically launched as separate tasks when launching the nodes.\n\nThe constructor for the node should initialize any variables and register the needed publishers and subscribers with NodeData.\n\nEach loop of the process will call the compute method once, which needs to be implemented by the user. A lock for each subscriber task is created in NodeData.sub_locks. It's recommended that the user obtains the lock and copies the data into a local variable for internal use by the compute function.\n\nLaunching the node\n\nThe blocking process that runs the node indefinately is called via run(node). It's recommended that this is launched asynchronously via\n\nnode_task = @task run(node)\nschedule(node_task)\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.NodeIO","page":"API","title":"Mercury.NodeIO","text":"NodeIO\n\nDescribes the input/output mechanisms for the node. Each node should store this type internally and add the necessary I/O mechanisms inside of the setupIO!(::NodeIO, ::Node) method.\n\nI/O mechanisms are added to a NodeIO object via add_publisher! and add_subscriber!.\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.PublishedMessage","page":"API","title":"Mercury.PublishedMessage","text":"Specifies a publisher along with specific message type. This is useful for tracking multiple messages at once\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.SerialPublisher","page":"API","title":"Mercury.SerialPublisher","text":"SerialPublisher\n\nWrite data over a serial port.\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.SerialPublisher-Tuple{String, Integer}","page":"API","title":"Mercury.SerialPublisher","text":"SerialPublisher(port_name::String, baudrate::Integer; [name])\n\nCreate a publisher attached to the serial port at port_name with a communicate rate of baudrate. Automatically tries to open the port.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.SerializedVICONcpp","page":"API","title":"Mercury.SerializedVICONcpp","text":"Used for listening to VICON messages\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.SubscribedMessage","page":"API","title":"Mercury.SubscribedMessage","text":"Specifies a subcriber along with specific message type. This is useful for tracking multiple messages at once\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.SubscribedVICON","page":"API","title":"Mercury.SubscribedVICON","text":"Specifies a subcriber along with specific message type. This is useful for tracking multiple messages at once\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.SubscriberFlags","page":"API","title":"Mercury.SubscriberFlags","text":"SubscriberFlags\n\nSome useful flags when dealing with subscribers. Describes the state of the system. Particularly helpful when the subscriber is actively receiving messages in another thread and you want to query the state of the subscriber.\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.ZmqPublisher","page":"API","title":"Mercury.ZmqPublisher","text":"Publisher\n\nA simple wrapper around a ZMQ publisher, but only publishes protobuf messages.\n\nConstruction\n\nPublisher(context::ZMQ.Context, ipaddr, port; name)\n\nTo create a publisher, pass in a ZMQ.Context, which allows all related publisher / subscribers to be collected in a \"group.\" The publisher also needs to be provided the IPv4 address (either as a string or as a Sockets.IPv4 object), and the port (either as an integer or a string).\n\nA name can also be optionally provided via the name keyword, which can be used to provide a helpful description about what the publisher is publishing. It defaults to \"publisher_#\" where # is an increasing index.\n\nIf the port\n\nUsage\n\nTo publish a message, just use the publish method on a protobuf type:\n\npublish(pub::Publisher, proto_msg::ProtoBuf.ProtoType)\n\n\n\n\n\n","category":"type"},{"location":"api.html#Mercury.ZmqSubscriber","page":"API","title":"Mercury.ZmqSubscriber","text":"ZmqSubscriber\n\nA simple wrapper around a ZMQ subscriber, but only for protobuf messages.\n\nConstruction\n\nSubscriber(context::ZMQ.Context, ipaddr, port; name)\n\nTo create a subscriber, pass in a ZMQ.Context, which allows all related publisher / subscribers to be collected in a \"group.\" The subscriber also needs to be provided the IPv4 address (either as a string or as a Sockets.IPv4 object), and the port (either as an integer or a string).\n\nA name can also be optionally provided via the name keyword, which can be used to provide a helpful description about what the subscriber is subscribing to. It defaults to \"subscriber_#\" where # is an increasing index.\n\nUsage\n\nUse the blocking subscribe method to continually listen to the socket and store data in a protobuf type:\n\nsubscribe(sub::Subscriber, proto_msg::ProtoBuf.ProtoType)\n\nNote that this function contains an infinite while loop so will block the calling thread indefinately. It's usually best to assign the process to a separate thread / task:\n\nsub_task = @task subscribe(sub, proto_msg)\nschedule(sub_task)\n\n\n\n\n\n","category":"type"},{"location":"api.html#Base.sleep-Union{Tuple{Mercury.LoopRateLimiter{UseSleep}}, Tuple{UseSleep}} where UseSleep","page":"API","title":"Base.sleep","text":"sleep(::LoopRateLimiter)\n\nSleep the OS for the amount of time needed to achieve the rate specified by the loop rate limiter. Has a minimum sleep time of 1 microsecond (relies on the usleep C function).\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.add_publisher!-Tuple{Mercury.NodeIO, Union{ProtoBuf.ProtoType, AbstractVector{UInt8}}, Mercury.Publisher}","page":"API","title":"Mercury.add_publisher!","text":"add_publisher!(nodeIO, msg, args...)\n\nAdds / registers a publisher to nodeIO. This method should only be called once per unique message, across all nodes in the network, since each message should only ever have one publisher. The msg can be any ProtoBuf.ProtoType message (usually generated using ProtoBuf.protoc). Since this is stored as an abstract ProtoBuf.ProtoType type internally, the user should store the original type inside the node.  The remaining arguments are passed directly to the constructor for Publisher.\n\nThis function adds a new PublishedMessage to nodeIO.pubs. During the compute     method, the user should modify the original concrete msg stored in the node. The     data can then be published by calling publish on the corresponding PublishedMessage.\n\nExample\n\nInside of the node constructor:\n\n...\ntest_msg = TestMsg(x = 1, y = 2, z= 3)\n...\n\nInside of setupIO!:\n\n...\nctx = ZMQ.Context()\nipaddr = ip\"127.0.0.1\"\nport = 5001\nadd_publisher!(nodeIO, node.test_msg, ctx, ipaddr, port, name=\"TestMsg_publisher\")\n...\n\nInside of compute:\n\n...\nnode.test_msg.x = 1  # modify the message as desired\npublish(getIO(node).pubs[1])  # or whichever is the correct index\n...\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.add_subscriber!-Tuple{Mercury.NodeIO, Union{ProtoBuf.ProtoType, AbstractVector{UInt8}}, Mercury.Subscriber}","page":"API","title":"Mercury.add_subscriber!","text":"add_subscriber!(nodeIO, msg, args...)\n\nAdds / registers a subscriber to nodeIO. The msg can be any ProtoBuf.ProtoType message (usually generated using ProtoBuf.protoc). Since this is stored as an abstract ProtoBuf.ProtoType type internally, the user should store the original type inside the node.  The remaining arguments are passed directly to the constructor for Subscriber.\n\nThis function adds a new SubscribedMessage to nodeIO.subs. A separate asynchronous task is created for each subscriber when the node is launched.  During the compute method, the user can access the latest data by reading from the message stored in their node. To avoid data races and minimize synchronization, it's usually best practice to obtain the lock on the message (stored in SubscribedMessage) and copy the data to a local variable (likely also stored in the node) that can be used by the rest of the compute method without worrying about the data being overwritted by the ongoing subscriber task.\n\nExample\n\nIn the node constructor:\n\n...\ntest_msg = TestMessage(x = 0, y = 0, z = 0)\n...\n\nIn setupIO!:\n\n...\nctx = ZMQ.Context()\nipaddr = ip\"127.0.0.1\"\nport = 5001\nadd_subscriber!(nodeIO, node.test_msg, ctx, ipaddr, port, name = \"TestMsg_subscriber\")\n...\n\nIn compute:\n\n...\ntestmsg = getIO(node).subs[1]  # or whichever is the correct index\nlock(testmsg.lock) do\n    node.local_test_msg = node.test_msg  # or convert to a different type\nend\n# use node.local_test_msg in the rest of the code\n...\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.decode!-Tuple{ProtoBuf.ProtoType, IOBuffer}","page":"API","title":"Mercury.decode!","text":"Read in the byte data into the message container buf. Returns the number of bytes read\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.decodeCOBS-Tuple{Mercury.SerialSubscriber, AbstractVector{UInt8}}","page":"API","title":"Mercury.decodeCOBS","text":"decodeCOBS(msg)\n\nUses COBS to decode message block.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.encodeCOBS-Tuple{Mercury.SerialPublisher, AbstractVector{UInt8}}","page":"API","title":"Mercury.encodeCOBS","text":"encode(pub::SerialPublisher, payload::AbstractVector{UInt8})\n\nZero Allocation COBS encoding of a message block\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.getpublisher","page":"API","title":"Mercury.getpublisher","text":"getpublisher(node, index)\ngetpublisher(node, name)\n\nGet a  PublishedMessage attached to node, either by it's integer index or it's name.\n\n\n\n\n\n","category":"function"},{"location":"api.html#Mercury.getsubscriber","page":"API","title":"Mercury.getsubscriber","text":"getsubscriber(node, index)\ngetsubscriber(node, name)\n\nGet a  SubscribedMessage attached to node, either by it's integer index or it's name.\n\n\n\n\n\n","category":"function"},{"location":"api.html#Mercury.launch-Tuple{Mercury.Node}","page":"API","title":"Mercury.launch","text":"launch(node)\n\nRun the main loop of the node indefinately. This method automatically sets up any necessary subscriber tasks and then calls the compute method at a fixed rate.\n\nThis method should typically be wrapped in an @async or @spawn call.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.numpublishers","page":"API","title":"Mercury.numpublishers","text":"numpublishers(node)\n\nGet the number of ZMQ publishers attached to the node\n\n\n\n\n\n","category":"function"},{"location":"api.html#Mercury.numsubscribers","page":"API","title":"Mercury.numsubscribers","text":"numsubscribers(node)\n\nGet the number of ZMQ subscribers attached to the node\n\n\n\n\n\n","category":"function"},{"location":"api.html#Mercury.on_new-Tuple{Function, Mercury.SubscribedMessage}","page":"API","title":"Mercury.on_new","text":"on_new(func::Function, submsg::SubscribedMessage)\n\nHelpful function for executing code blocks when a SubscribedMessage type has recieved a new message on its Subscriber's Socket. The function func is expected to have a signature of func(msg::ProtoBuf.ProtoType) where msg is the message which submsg has recieved.\n\nExample:\n\non_new(nodeio.subs[1]) do msg\n    println(msg.pos_x)\nend\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.publish_until_receive","page":"API","title":"Mercury.publish_until_receive","text":"publish_until_receive(pub, sub, msg_out; [timeout])\n\nPublish a message via the publisher pub until it's received by the subscriber sub. Both pub and sub should have the same port and IP address.\n\nThe function returns true if a message was received before timeout seconds have passed,     and false otherwise.\n\n\n\n\n\n","category":"function"},{"location":"api.html#Mercury.receive-Tuple{Mercury.SerialSubscriber, Any, ReentrantLock}","page":"API","title":"Mercury.receive","text":"Returns true if successfully read message from serial port\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.receive-Tuple{Mercury.ZmqSubscriber, Mercury.SerializedVICON}","page":"API","title":"Mercury.receive","text":"Useful functions for communicating with serial VICON\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.reset!-Tuple{Mercury.LoopRateLimiter}","page":"API","title":"Mercury.reset!","text":"reset!(::LoopRateLimiter)\n\nReset the loop rate limiter before a loop. Not necessary if the object is created directly before calling the loop.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.startloop-Tuple{Mercury.LoopRateLimiter}","page":"API","title":"Mercury.startloop","text":"startloop(::LoopRateLimiter)\n\nCall this function at the beginning of a loop body to start timing the loop.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.usleep-Tuple{Any}","page":"API","title":"Mercury.usleep","text":"usleep(us)\n\nSleep for us microseconds. A wrapper around the C usleep function in unistd.h.\n\n\n\n\n\n","category":"method"},{"location":"api.html#Mercury.@rate-Tuple{Any, Any}","page":"API","title":"Mercury.@rate","text":"@rate\n\nRun a loop at a fixed rate, specified either by an integer literal or a LoopRateLimiter object. It will run the loop so that it executes close to rate iterations per second.\n\nExamples\n\n@rate for i = 1:100\n    myexpensivefunction()\nend 200#Hz\n\nlr = LoopRateLimiter(200, N_batch=10)\n@rate while i < 100\n    myexpensivefunction()\n    i += 1\nend lr\n\nNote that the following does NOT work:\n\nrate = 100\n@rate for i = 1:100\n    myexpensivefunction()\nend rate\n\nSince Julia macros dispatch on the compile-time types instead of the run-time types.\n\n\n\n\n\n","category":"macro"},{"location":"index.html#Mercury","page":"Introduction","title":"Mercury","text":"","category":"section"},{"location":"index.html#Overview","page":"Introduction","title":"Overview","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"Mercury.jl is a light-weight message passing system for robotics applications built  on top of ZMQ.jl and ProtoBuf.jl. It's main goal is to provide a fast and efficient  method for setting up autonomy stacks on embedded systems or microcomputers. ","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"This project is still in early development by the Robotic Exploration Lab at Carnegie Mellon University. The package will be registered  as an official Julia package as soon as we get it working reliably on real hardware.","category":"page"}]
}
