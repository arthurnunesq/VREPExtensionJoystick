require 'class'
api = require('api')
ModelComponentScriptBase = require('ModelComponentScriptBase')
Vehicle = require('Vehicle')
JoyState = require('JoyState')
PID = require('PID')

local VehicleLogitechG920ControllerHandler = class(ModelComponentScriptBase, function(self, scriptHandle)
    -- simAddStatusbarMessage("VehicleLogitechG920ControllerHandler ctor")

    ModelComponentScriptBase.init(self, scriptHandle)

    self.vehicle = Vehicle(self.modelScriptHandle)
    self.manualControlSourceId = "LogitechG920Controller"
    self.pid_graph = api.simGetChildObjectHandle(self.vehicle.objHandle, 'LogitechG920ControllerPIDGraph')

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
    self.joyId = simGetScriptSimulationParameter(self.scriptHandle, 'joyId')
    self.throttleSensibility = simGetScriptSimulationParameter(self.scriptHandle, 'throttleSensibility')

    -- ==============================================================
    -- SIGNALS DEFINITIONS
    -- ==============================================================
    self.recordOdomSignalName = api.getSignalName(self.vehicle.vehicleName, 'RecordOdom')

    -- ==============================================================
    -- JOYSTICK STATUS
    -- ==============================================================
    self.manualControlSourceId = "LogitechG920Controller"
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

    -- ==============================================================
    -- POSITION CONTROL
    -- ==============================================================
    self.position_controller = PID()
end)

function VehicleLogitechG920ControllerHandler:firstExecution()
end

function VehicleLogitechG920ControllerHandler:initialization()
    if(self:isControllerConnected()) then
        self.vehicle:setManualControlSource(self.manualControlSourceId)
    end
end

function VehicleLogitechG920ControllerHandler:actuation()
    if(not self.enabled) then
        return
    end

    -- Controller state ==============================================  
    if(not self:isControllerConnected()) then
        return
    end

    if (self.require_focus and simGetObjectLastSelection() ~= self.modelHandle) then 
        return
    end

    self:refresh()

    if( self:isStartPressed() 
        or self:isBackPressed()
    ) then
        self.vehicle:setManualControlSource(self.manualControlSourceId)
    end

    -- Command Mapping ==============================================    
    throttleCommand = api.applySensibility(self:getThrottle(), self.throttleSensibility)
    brakeCommand = self:getBrakes()
    steeringCommand = self:getSteering()

    gearNeutralCommand = true;
    gearDriveCommand = self:isGear3Pressed();
    gearReverseCommand = self:isGear4Pressed();

    recordOdomCommand = self:isLBPressed()
    recordOdomCommandChanged = self:hasLBChanged()

    cruiseControlCommand = self:isRBPressed()
    cruiseControlCommandChanged = self:hasRBChanged()

    parkingBrakeCommand = self:isGearReversePressed()
    parkingBrakeCommandChanged =  self:hasGearReverseChanged()

    -- Command interpretation ============================================== 
    
    if(not self.cruiseControlState) then
        self.refSpeed = 0
    end
    self.refServiceBrakeTorque = 0

    if(throttleCommand > 0) then
        if(not self.cruiseControlState) then
            self.refSpeed = self.vehicle.maxSpeed*throttleCommand  
        end
    end
    if(brakeCommand > 0) then
        self.refServiceBrakeTorque = self.vehicle.maxServiceBrakeTorque*brakeCommand
        if(self.cruiseControlState) then
            self:log("Brake pressed: Cruise control deactivated")
            self.cruiseControlState = false;
        end
    end
    if (parkingBrakeCommandChanged) then
        if(parkingBrakeCommand) then
            self:log("Parking brake activated")
            self.refParkingBrakeTorque = self.vehicle.maxParkingBrakeTorque
        else
            self:log("Parking brake deactivated")
            self.refParkingBrakeTorque = 0
        end
    end

    self.refSteeringAngle = self.vehicle.maxSteeringAngle*(-steeringCommand)

    if (gearNeutralCommand) then
        self.refGear = Vehicle.GEAR_NEUTRAL;
    end
    if (gearDriveCommand) then
        self.refGear = Vehicle.GEAR_FORWARD;
    end
    if (gearReverseCommand) then
        self.refGear = Vehicle.GEAR_REVERSE;
    end

    if (cruiseControlCommandChanged and cruiseControlCommand) then
        self.cruiseControlState = not self.cruiseControlState
        if(self.cruiseControlState) then
            self:log(string.format("Cruise control activated: %f m/s", self.refSpeed))
        else
            self:log("Cruise control deactivated")
        end
    end
    
    if (recordOdomCommandChanged and recordOdomCommand) then
        self.recordOdom = (self.recordOdom+1)%2
    end


    -- Position control ============================================== 

    self.position_controller.setpoint = self:getThrottle()
    self.position_controller:step(self:getSteering())
    self:setForce(self.position_controller.control_effort)

    if(self.pid_graph ~= nil) then
        simSetGraphUserData(self.pid_graph, "e", self.position_controller.error[1])
        simSetGraphUserData(self.pid_graph, "u", self.position_controller.control_effort)
    end

    -- self:setForce(self:getThrottle())
          
    -- Signals ============================================== 
    if(self.vehicle:isManualControlSource(self.manualControlSourceId)) then
        simSetFloatSignal(self.vehicle.manualRefSpeedSignalName, self.refSpeed)
        simSetFloatSignal(self.vehicle.manualRefSteeringAngleSignalName, self.refSteeringAngle)
        simSetFloatSignal(self.vehicle.manualRefServiceBrakeTorqueSignalName, self.refServiceBrakeTorque)
        simSetFloatSignal(self.vehicle.manualRefParkingBrakeTorqueSignalName, self.refParkingBrakeTorque)
        simSetIntegerSignal(self.vehicle.manualRefGearSignalName, self.refGear)
        simSetIntegerSignal(self.recordOdomSignalName, self.recordOdom)
    end

    -- str ="\n"
    -- str = str .. "refSpeed = " .. self.refSpeed .. "\n"
    -- str = str .. "refSteeringAngle = " .. self.refSteeringAngle .. "\n"
    -- str = str .. "refServiceBrakeTorque = " .. self.refServiceBrakeTorque .. "\n"
    -- str = str .. "refParkingBrakeTorque = " .. self.refParkingBrakeTorque .. "\n"
    -- str = str .. "refGear = " .. self.refGear .. "\n"
    -- str = str .. "recordOdom = " .. self.recordOdom .. "\n"
    -- self:log(str)

end

function VehicleLogitechG920ControllerHandler:sensing()    
end

function VehicleLogitechG920ControllerHandler:cleanup()
    self:setForce(0.0)
end

function VehicleLogitechG920ControllerHandler:isControllerConnected()
    if(not self.enabled) then
        return false
    end

    if (simExtJoyGetCount() == 0) then
        if (self.lastIsConnectedState == nil or self.lastIsConnectedState) then
            self.lastIsConnectedState = false;
            self:log("ERROR: Logitech G920 Controller NOT connected.")
        end
        return false
    end

    if (self.lastIsConnectedState == nil or not self.lastIsConnectedState) then
        self.lastIsConnectedState = true;
        self:log("Logitech G920 Controller connected.")
    end

    return true
end

function VehicleLogitechG920ControllerHandler:refresh()
    axes, buttons, rotAxes, slider, pov= simExtJoyGetData(self.joyId)
    self.previousJoyState = self.joyState
    self.joyState = JoyState(axes, buttons, rotAxes, slider, pov)
    -- self:log(self.joyState:toString())
end

function VehicleLogitechG920ControllerHandler:setForce(force)
    simExtJoySetForces(self.joyId, -force)
end

function VehicleLogitechG920ControllerHandler:isStartPressed()
    return self.joyState:getButton(6)
end

function VehicleLogitechG920ControllerHandler:isBackPressed()
    return self.joyState:getButton(7)
end

function VehicleLogitechG920ControllerHandler:isXboxPressed()
    return self.joyState:getButton(10)
end

function VehicleLogitechG920ControllerHandler:isLBPressed()
    return self.joyState:getButton(5)
end

function VehicleLogitechG920ControllerHandler:isRBPressed()
    return self.joyState:getButton(4)
end

function VehicleLogitechG920ControllerHandler:isLSBPressed()
    return self.joyState:getButton(9)
end

function VehicleLogitechG920ControllerHandler:isRSBPressed()
    return self.joyState:getButton(8)
end

function VehicleLogitechG920ControllerHandler:isYPressed()
    return self.joyState:getButton(3)
end

function VehicleLogitechG920ControllerHandler:isBPressed()
    return self.joyState:getButton(1)
end

function VehicleLogitechG920ControllerHandler:isAPressed()
    return self.joyState:getButton(0)
end

function VehicleLogitechG920ControllerHandler:isXPressed()
    return self.joyState:getButton(2)
end

function VehicleLogitechG920ControllerHandler:isGear1Pressed()
    return self.joyState:getButton(12)
end
function VehicleLogitechG920ControllerHandler:isGear2Pressed()
    return self.joyState:getButton(13)
end
function VehicleLogitechG920ControllerHandler:isGear3Pressed()
    return self.joyState:getButton(14)
end
function VehicleLogitechG920ControllerHandler:isGear4Pressed()
    return self.joyState:getButton(15)
end
function VehicleLogitechG920ControllerHandler:isGear5Pressed()
    return self.joyState:getButton(7) -- UNKNOWN
end
function VehicleLogitechG920ControllerHandler:isGear6Pressed()
    return self.joyState:getButton(7) -- UNKNOWN
end
function VehicleLogitechG920ControllerHandler:isGearReversePressed()
    return self.joyState:getButton(11)
end

function VehicleLogitechG920ControllerHandler:getSteering()
    return self.joyState.axes[1] / 1000.0
end

function VehicleLogitechG920ControllerHandler:getThrottle()
    return 1 - ( (self.joyState.axes[2] / JoyState.MAX_AXE_VALUE) + 1)/2
end

function VehicleLogitechG920ControllerHandler:getBrakes()
    return 1 - ( (self.joyState.rotAxes[3] / JoyState.MAX_AXE_VALUE) + 1)/2
end

function VehicleLogitechG920ControllerHandler:getClutch()
    return JoyState.MAX_AXE_VALUE - (self.joyState.slider[1] / JoyState.MAX_AXE_VALUE)
end

function VehicleLogitechG920ControllerHandler:hasLBChanged()
    return (self.joyState ~= nil) and (self.previousJoyState ~= nil) and (self.joyState:getButton(5) ~= self.previousJoyState:getButton(5))
end

function VehicleLogitechG920ControllerHandler:hasRBChanged()
    return (self.joyState ~= nil) and (self.previousJoyState ~= nil) and (self.joyState:getButton(4) ~= self.previousJoyState:getButton(4))
end

function VehicleLogitechG920ControllerHandler:hasGearReverseChanged()
    return (self.joyState ~= nil) and (self.previousJoyState) ~= nil and (self.joyState:getButton(11) ~= self.previousJoyState:getButton(11))
end


return VehicleLogitechG920ControllerHandler