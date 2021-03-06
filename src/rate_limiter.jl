"""
    usleep(us)

Sleep for `us` microseconds. A wrapper around the C `usleep` function in `unistd.h`.
"""
function usleep(us)
    ccall((:MicroSleep, libhg), Cvoid, (Cint,), us)
end

"""
    LoopRateLimiter

Runs a loop at a fixed rate. Works best for loops where the runtime is approximately
the same every iteration. The loop runtime is kept approximately constant by sleeping
for any time not used by the core computation. This is useful for situations where
the computation should take place a regular, predictable intervals.

To achieve better accuracy, the rate limiter records the error between the expected
runtime and actual runtime every `N_batch` iterations, and adjusts the sleep time
by the average. Unlike the standard sleep function in Julia, this limiter has a
minimum sleep time of 1 microsecond, and rates above 1000Hz can be achieved with
moderate accuracy.

# Example
```
lrl = LoopRateLimiter(100)  # Hz
reset!(lrl)
for i = 1:100
    startloop(lrl)          # start timing the loop
    myexpensivefunction()   # execute the core body of the loop
    sleep(lrl)              # sleep for the rest of the time
end
```
"""
mutable struct LoopRateLimiter{UseSleep}
    rate::Float64    # target rate (Hz)
    ns_target::Int   # target loop time (ns)
    N_batch::Int     # number of loops before estimating the timing offset
    us_offset::Int   # sleep offset, estimated online (us)
    t_batch::UInt64  # start time of last batch (ns)
    t_start::UInt64  # start time of the loop (ns)
    i_batch::Int
    function LoopRateLimiter{UseSleep}(rate; N_batch = 10) where {UseSleep}
        @assert UseSleep isa Bool
        ns_target = round(Int, 1 / rate * 1_000_000_000)
        new{UseSleep}(rate, ns_target, N_batch, 0, 0, 0, 0)
    end
end
function LoopRateLimiter(rate; N_batch = 10)
    use_sleep = rate < 50
    LoopRateLimiter{use_sleep}(rate, N_batch = N_batch)
end

doesblock(::LoopRateLimiter{UseSleep}) where {UseSleep} = !UseSleep

"""
    reset!(::LoopRateLimiter)

Reset the loop rate limiter before a loop. Not necessary if the object is created directly
before calling the loop.
"""
function reset!(lrl::LoopRateLimiter; all::Bool = true)
    lrl.i_batch = 0
end

"""
    startloop(::LoopRateLimiter)

Call this function at the beginning of a loop body to start timing the loop.
"""
function startloop(lrl::LoopRateLimiter)
    lrl.t_start = time_ns()
    us2ns = 1000
    if lrl.i_batch == 0  # very first time the loop is called
        lrl.t_batch = lrl.t_start
    end
    if lrl.i_batch == lrl.N_batch
        t_batch_expected = Int(lrl.ns_target * lrl.N_batch)
        t_batch_actual = Int(lrl.t_start - lrl.t_batch)
        us_error = (t_batch_actual - t_batch_expected) ?? us2ns ?? lrl.N_batch
        lrl.us_offset += us_error  # update the estimate of the offset
        lrl.t_batch = lrl.t_start
        lrl.i_batch = 1            # reset the batch loop count
    else
        lrl.i_batch += 1           # increment the batch loop count
    end
end

"""
    sleep(::LoopRateLimiter)

Sleep the OS for the amount of time needed to achieve the rate specified by the loop rate
limiter. Has a minimum sleep time of 1 microsecond (relies on the `usleep` C function).
"""
@generated function Base.sleep(lrl::LoopRateLimiter{UseSleep}) where {UseSleep}
    local sleep_code
    if UseSleep
        sleep_code = quote
            sleep(us_diff / 1e6)
            # usleep(us_diff)
        end
    else
        sleep_code = quote
            usleep(us_diff)
        end
    end
    quote
        us2ns = 1000
        t_stop = time_ns()
        ns_elapsed = round(Int, t_stop - lrl.t_start)
        ns_diff = lrl.ns_target - ns_elapsed                   # time error (ns)
        us_diff = round(Int, ns_diff ?? us2ns) - lrl.us_offset  # sleep time (us)
        if (us_diff > 0)
            $sleep_code
            # if lrl.use_sleep 
            #     sleep(us_diff / 1e6)
            # else
            # tsleep = @async usleep(us_diff)
            # while (!istaskdone(tsleep))
            # end
            # usleep(us_diff)
            # yield()
            # wait(tsleep)
            # end
            # sleep(us_diff / 1000.0)
        end
    end
end

"""
    @rate

Run a loop at a fixed rate, specified either by an integer literal or a
`LoopRateLimiter` object. It will run the loop so that it executes close
to `rate` iterations per second.

# Examples
```
@rate for i = 1:100
    myexpensivefunction()
end 200#Hz
```

```
lr = LoopRateLimiter(200, N_batch=10)
@rate while i < 100
    myexpensivefunction()
    i += 1
end lr
```

Note that the following does NOT work:
```
rate = 100
@rate for i = 1:100
    myexpensivefunction()
end rate
```
Since Julia macros dispatch on the compile-time types instead of the run-time types.
"""
macro rate(loop, lrl)

    # Make sure it's actually a loop
    if loop.head ??? (:for, :while)
        error("@atrate macro can only be used before for or while loops.")
    end

    # Modify the loop body
    bodyblock = loop.args[2]
    newbody = quote
        startloop($(esc(lrl)))
        $(esc(bodyblock))
        sleep($(esc(lrl)))
    end
    loop.args[1] = esc(loop.args[1])
    loop.args[2] = newbody

    return loop
end

macro rate(loop, rate::Real)

    # Make sure it's actually a loop
    if loop.head ??? (:for, :while)
        error("@atrate macro can only be used before for or while loops.")
    end

    # Modify the loop body
    bodyblock = loop.args[2]
    newbody = quote
        startloop(lrl)
        $(esc(bodyblock))
        sleep(lrl)
    end
    loop.args[1] = esc(loop.args[1])
    loop.args[2] = newbody

    expr = quote
        lrl = LoopRateLimiter($rate)
        $loop
    end

    return expr
end
