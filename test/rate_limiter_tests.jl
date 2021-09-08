import Mercury as Hg
import Mercury: LoopRateLimiter
using LinearAlgebra
using StaticArrays
using Statistics
using Test

@testset "Rate Limited Loops" begin
    function runrate(f, lrl::LoopRateLimiter, time_s = 1)
        N = round(Int, lrl.rate * time_s)
        times = zeros(N)
        Hg.reset!(lrl)
        for i = 1:N
            times[i] = @elapsed begin
                Hg.startloop(lrl)
                f()
                sleep(lrl)
            end
        end
        return 1 ./ times
    end

    @generated function runrate_macro1(f, ::Val{rate}, time_s = 1) where {rate}
        quote
            N = round(Int, $rate * time_s)
            lrl = LoopRateLimiter(rate)
            t_start = time_ns()
            Hg.@rate for i = 1:N
                f()
            end $rate
            t_elapsed = (time_ns() - t_start) * 1e-9
            return N / t_elapsed
        end
    end

    function runrate_macro2(f, rate, time_s = 1)
        N = round(Int, rate * time_s)
        lrl = LoopRateLimiter(rate)
        t_start = time_ns()
        Hg.@rate for i = 1:N
            f()
        end lrl
        t_elapsed = (time_ns() - t_start) * 1e-9
        return N / t_elapsed
    end

    @generated function runrate_macro3(f, ::Val{rate}, time_s = 1) where {rate}
        quote
            N = round(Int, $rate * time_s)
            lrl = LoopRateLimiter(rate)
            t_start = time_ns()
            i = 0
            Hg.@rate while (i < N)
                f()
                i += 1
            end $rate
            t_elapsed = (time_ns() - t_start) * 1e-9
            return N / t_elapsed
        end
    end

    function runrate_macro4(f, rate, time_s = 1)
        N = round(Int, rate * time_s)
        lrl = LoopRateLimiter(rate)
        t_start = time_ns()
        i = 0
        Hg.@rate while (i < N) 
            f()
            i += 1
        end lrl
        t_elapsed = (time_ns() - t_start) * 1e-9
        return N / t_elapsed
    end

    ##
    function mykernel()
        A = @SMatrix randn(10, 10)
        B = @SMatrix randn(10, 10)
        C = A'A + B'B
        x = @SVector randn(10)
        cholA = cholesky(Symmetric(C))
        C \ x
    end
    1 / @elapsed mykernel()

    rate = 1000
    test_time = 0.1 # sec
    lrl = LoopRateLimiter(rate)
    error = (rate - median(runrate(mykernel, lrl, test_time))) / rate * 100
    @test error < 5  # less than 5% error

    error = (rate - runrate_macro1(mykernel, Val(rate), test_time)) / rate * 100
    @test error < 5  # less than 5% error
    error = (rate - runrate_macro2(mykernel, rate, test_time)) / rate * 100
    @test error < 5  # less than 5% error
    error = (rate - runrate_macro3(mykernel, Val(rate), test_time)) / rate * 100
    @test error < 5  # less than 5% error
    error = (rate - runrate_macro4(mykernel, rate, test_time)) / rate * 100
    @test error < 5  # less than 5% error

end
