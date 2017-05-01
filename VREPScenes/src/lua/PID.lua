require 'class'

-- https://bitbucket.org/AndyZe/pid/src/31105f05b463573c020800d2cef81307d9a98579/src/controller.cpp?at=master&fileviewer=file-view-default

local PID = class(function(self)

    self.plant_state = 0.0              -- current output of plant
    self.control_effort = 0.0    -- output of pid controller
    self.setpoint = 0.0          -- desired output of plant
    self.pid_enabled = false         -- PID is enabled to run

    self.prev_time = nil;
    self.delta_t = 0.0

    self.error_integral = 0.0
    self.proportional = 0.0      -- proportional term of output
    self.integral = 0.0          -- integral term of output
    self.derivative = 0.0        -- derivative term of output

    -- Upper and lower saturation limits
    self.upper_limit =  1.0
    self.lower_limit = -1.0

    -- Anti-windup term. Limits the absolute value of the integral term.
    self.windup_limit = 1000

    self.Kp = 1.0
    self.Kd = 0.0
    self.Ki = 0.0

    self.error = {0.0, 0.0, 0.0}
end)

-- function PID:setpoint(setpoint)
--     self.setpoint = setpoint
-- end

function PID:step(plant_state)
    if ( not((self.Kp <= 0.0 and self.Ki<=0.0 and self.Kd<=0.0) or (self.Kp>=0.0 and self.Ki>=0.0 and self.Kd>=0.0)) ) -- All 3 gains should have the same sign
    then
        self.log("All three gains (Kp, Ki, Kd) should have the same sign for stability.");
    end

    self.plant_state = plant_state
    self.control_effort = self.setpoint

    return self.control_effort
end

return PID

