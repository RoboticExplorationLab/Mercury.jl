mutable struct Logger <: Node
    LoggerIO::NodeIO
    rate::Float64 = 100.0
    should_finish::Bool = false

    log_task::Union{Nothing, Task}

    write_dir::String = joinpath(pwd(), "log")
    write_files::Vector{String}

    function Logger() # TODO
        rate = 100.0
        should_finish = false
        log_task = nothing

        write_dir = joinpath(pwd(), "log")
        if !isdir(write_dir)
            mkdir(write_dir)
        end

        new(LoggerIO, LoggerOpts, rate, should_finish, log_task, write_dir, write_files)
    end
end

function start_logging(logger::Logger)
    logger.log_task = @task launch(logger)
    schedule(node_task)
end

function stop_logging(logger::Logger)
    logger.should_finish = true
    wait(logger.log_task)

    return true
end

# function add_log!(logger::Logger, msg::ProtoBuf.ProtoType, args...)
#     push!(logger.logs, SubscribedMessage(msg, Subscriber(args...)))
# end

# function add_serial_log!(logger::Logger, msg::ProtoBuf.ProtoType, args...)
#     push!(logger.logs, SubscribedMessage(msg, SerialSubscriber(args...)))
# end


log