"""
This script tests a serial publisher. It sends 1 byte messages to an Arduino located at
/dev/ttyUSB0. You can use the Arduino script `SerialBlink` to verify the messages are 
received. The LED on the Arduino should incrementally blink fast 1-5 times twice.
"""
import Mercury as Hg
using Test

pub = Hg.SerialPublisher("/dev/ttyUSB0", 57600);
stop = Threads.Atomic{Bool}(false)
pub_task = @async begin
    Hg.@rate for i = 1:10
        numblinks = UInt8(mod1(i,5))
        println("Blinking $numblinks times")
        Hg.publish(pub, UInt8[numblinks])
        if stop[]
            println("Stopping")
            break
        end
    end 1.0
end
wait(pub_task)
@test !istaskfailed(pub_task)
close(pub)