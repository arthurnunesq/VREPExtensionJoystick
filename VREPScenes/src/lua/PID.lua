require 'class'
api = require('api')

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

    self.deadband = 0.03

    self.Kp = 1.0
    self.Kd = 0.0
    self.Ki = 0.2

    self.error = {0.0, 0.0, 0.0}
    self.error_without_deadband = 0.0
    self.error_deriv = {0.0, 0.0, 0.0}
end)

-- function PID:setpoint(setpoint)
--     self.setpoint = setpoint
-- end

function PID.apply_deadband(ui, deadband)
    local uo = 0.0
    if(ui < -deadband) then
        uo = ui + deadband
    end
    if(ui > deadband) then
        uo = ui - deadband
    end

    return uo
end


function PID:step(plant_state)
    if ( not((self.Kp <= 0.0 and self.Ki<=0.0 and self.Kd<=0.0) or (self.Kp>=0.0 and self.Ki>=0.0 and self.Kd>=0.0)) ) -- All 3 gains should have the same sign
    then
        self.log("All three gains (Kp, Ki, Kd) should have the same sign for stability.");
    end

    self.plant_state = plant_state

    self.error[3] = self.error[2];
    self.error[2] = self.error[1];
    self.error[1] = self.setpoint - self.plant_state; -- Current error goes to slot 0
    self.error_without_deadband = PID.apply_deadband(self.error[1], self.deadband)

    -- for i=-0, 2 do
    --   simAddStatusbarMessage('Error[' .. i .. '] = ' .. self.error[i])
    -- end

    -- calculate delta_t
    if(self.prev_time == nil) then
        self.prev_time = simGetSimulationTime()
        self.delta_t = 0.0
    else
        self.delta_t = simGetSimulationTime() - self.prev_time
        self.prev_time = simGetSimulationTime()
    end

    -- integrate the error
    self.error_integral = self.error_integral + self.error_without_deadband * self.delta_t;
    self.error_integral = api.saturate( self.error_integral, -self.windup_limit,  self.windup_limit)

    -- Take derivative of error
    -- First the raw, unfiltered data:
    self.error_deriv[3] = self.error_deriv[2]
    self.error_deriv[2] = self.error_deriv[1]
    self.error_deriv[1] = (self.error[1] - self.error[2])/self.delta_t;

    -- calculate the control effort
    self.proportional = self.Kp * self.error_without_deadband --filtered_error[0]
    self.integral = self.Ki * self.error_integral
    self.derivative = self.Kd * self.error_deriv[1] --filtered_error_deriv[0]
    self.control_effort = self.proportional + self.integral + self.derivative

    -- self.control_effort = self.setpoint

    return self.control_effort
end

return PID

