
Base.@kwdef mutable struct RateInfo
    enable::Bool = true
    num_batch::Int = 200
    t_start::UInt64 = 0
    cnt::Int = 0
    name::String = ""
end

function init(rate::RateInfo, name::String) 
    rate.name = name
    if rate.cnt == 0
        rate.t_start = time_ns()
    end
end

function printrate(rate::RateInfo)
    if rate.enable && rate.cnt == rate.num_batch
        t_stop = time_ns()
        ns_elapsed = time_ns() - rate.t_start
        avg_rate = rate.num_batch / (ns_elapsed * 1e-9)
        println("Average rate of $(rate.name): ", avg_rate, " Hz")
        rate.t_start = t_stop
        rate.cnt = 0
    end
    rate.cnt += 1
end