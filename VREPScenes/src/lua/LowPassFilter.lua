require 'class'
api = require('api')

-- https://bitbucket.org/AndyZe/pid/src/31105f05b463573c020800d2cef81307d9a98579/src/controller.cpp?at=master&fileviewer=file-view-default

local LowPassFilter = class(function(self, sample_rate, cutoff_frequency)
    if(sample_rate == nil) then
        sample_rate = 1
    end
    if(cutoff_frequency == nil) then
        cutoff_frequency = -1
    end

    self.sample_rate = sample_rate

    -- Filtering
    -- Cutoff frequency for the derivative calculation in Hz.
    -- Negative -> Has not been set by the user yet, so use a default.
    self.cutoff_frequency = cutoff_frequency
    -- Used in filter calculations. Default 1.0 corresponds to a cutoff frequency at
    -- 1/4 of the sample rate.
    self.c = 1.0
    -- Used to check for tan(0)==>NaN in the filter calculation
    self.tan_filt = 1.0

      -- My filter reference was Julius O. Smith III, Intro. to Digital Filters With Audio Applications.
    if (self.cutoff_frequency ~= -1) then
        -- Check if tan(_) is really small, could cause c = NaN
        self.tan_filt = math.tan( (self.cutoff_frequency*6.2832)*(1/self.sample_rate)/2 );
        simAddStatusbarMessage("Filter sample rate = " .. self.sample_rate)
        simAddStatusbarMessage("Filter cutoff frequency = " .. self.cutoff_frequency)
        simAddStatusbarMessage("Filter tan = " .. self.tan_filt)

        -- Avoid tan(0) ==> NaN
        if ( (self.tan_filt <= 0.) and (self.tan_filt > -0.01) ) then
          self.tan_filt = -0.01;
        end
        if ( (self.tan_filt >= 0.) and (self.tan_filt < 0.01) ) then
          self.tan_filt = 0.01;
        end

        self.c = 1/self.tan_filt;
        simAddStatusbarMessage("Filter c = " .. self.c)

    end

    self.u = {0.0, 0.0, 0.0}
    self.y = {0.0, 0.0, 0.0}
end)


function LowPassFilter:process(u)
    self.u[3] = self.u[2];
    self.u[2] = self.u[1];
    self.u[1] = u;

    self.y[3] = self.y[2];
    self.y[2] = self.y[1];
    self.y[1] = (1/(1+self.c*self.c+1.414*self.c))
        *(  self.u[3]+2*self.u[2]+self.u[1]
            -(self.c*self.c-1.414*self.c+1)*self.y[3]
            -(-2*self.c*self.c+2)*self.y[2]
        )

    return self.y[1]
end

return LowPassFilter

