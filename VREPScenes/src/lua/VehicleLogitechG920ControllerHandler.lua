require 'class'
api = require('api')
ModelComponentScriptBase = require('ModelComponentScriptBase')
Vehicle = require('Vehicle')

local VehicleLogitechG920ControllerHandler = class(ModelComponentScriptBase, function(self, scriptHandle)
    -- simAddStatusbarMessage("VehicleLogitechG920ControllerHandler ctor")

    ModelComponentScriptBase.init(self, scriptHandle)

    self.vehicle = Vehicle(self.modelScriptHandle)
    self.manualControlSourceId = "LogitechG920Controller"

   -- ==============================================================
    -- ENABLED
    -- ==============================================================
    self.enabled = simGetScriptSimulationParameter(self.scriptHandle, 'enabled')
    if(self.enabled) then
        self:log("Enabled.")
    end
    self.pluginLoaded = simExtJoyGetCount ~= nil
    if(self.enabled and not self.pluginLoaded) then
        self:log("Plugin wasn't loaded.")
        self.enabled = false
    end
    self.require_focus = simGetScriptSimulationParameter(self.scriptHandle, 'requireFocus')
    if(self.require_focus) then
        self:log("Focus required. Select the model before controlling it.")
    end

    -- ==============================================================
    -- PARAMS
    -- ==============================================================
    self.throttleSensibility = simGetScriptSimulationParameter(self.scriptHandle, 'throttleSensibility')

    -- ==============================================================
    -- SIGNALS DEFINITIONS
    -- ==============================================================
    self.recordOdomSignalName = api.getSignalName(self.vehicle.vehicleName, 'RecordOdom')

    -- ==============================================================
    -- JOYSTICK STATUS
    -- ==============================================================
    -- Status
    self.refSpeed = 0;
    self.refSteeringAngle = 0;
    self.refServiceBrakeTorque = 0;
    self.refParkingBrakeTorque = 0;
    self.refGear = 0
    self.parkingBrakeActivated = 0
    self.cruiseControlState = false
    self.recordOdom = 0
    -- Joystick helpers
    self.leftThumbStickCoordsDeadzone = 0.0;
    self.rightThumbStickCoordsDeadzone = 0.0;
    self.leftTriggerPressureDeadzone = 0.00
    self.rightTriggerPressureDeadzone = 0.00
    self.lastIsConnectedState = nil
    self.lastIsLeftShoulderPressedState = false
    self.lastIsRightShoulderPressedState = false
    self.lastIsRightThumbStickPressedState = nil
end)

function VehicleLogitechG920ControllerHandler:firstExecution()
end

function VehicleLogitechG920ControllerHandler:initialization()
    if(self.isControllerConnected()) then
        self.vehicle.setManualControlSource(self.manualControlSourceId)
    end
end

function VehicleLogitechG920ControllerHandler:actuation()
end

function VehicleLogitechG920ControllerHandler:sensing()
end

function VehicleLogitechG920ControllerHandler:cleanup()
end

function VehicleLogitechG920ControllerHandler:isControllerConnected()

end


return VehicleLogitechG920ControllerHandler