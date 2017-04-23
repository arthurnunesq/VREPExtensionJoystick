require 'class'
bitx = require('bitx')

local JoyState = class(function(self,axes, buttons, rotAxes, slider, pov)
    self.axes = axes
    self.buttons = buttons
    self.rotAxes = rotAxes
    self.slider = slider
    self.pov = pov
end)

function JoyState:getButton(buttonId)
    local flag = bitx.lshift(1, buttonId)
    return bitx.band(self.buttons, flag) == flag
end

function JoyState:toString(buttonId)
    local str = "\n"
    for i, item in ipairs(self.axes) do
        str = str .. "axes[" .. i .. "] = " .. tostring(self.axes[i]) .. "\n"
    end
    for i, item in ipairs(self.rotAxes) do
        str = str .. "rotAxes[" .. i .. "] = " .. tostring(self.rotAxes[i]) .. "\n"
    end
    for i, item in ipairs(self.slider) do
        str = str .. "slider[" .. i .. "] = " .. tostring(self.slider[i]) .. "\n"
    end
    for i, item in ipairs(self.pov) do
        str = str .. "pov[" .. i .. "] = " .. tostring(self.pov[i]) .. "\n"
    end
    for i = 0,15 do 
        str = str .. "button[" .. i .. "] = " .. tostring(self:getButton(i)) .. "\n"
    end
    return str
end

JoyState.MAX_AXE_VALUE = 1000.0

return JoyState
