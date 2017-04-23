require 'class'
api = require('api')
ChildScriptBase = require('ChildScriptBase')

local Vehicle = class(ChildScriptBase, function(self,scriptHandle)
    -- simAddStatusbarMessage("Vehicle ctor")

    ChildScriptBase.init(self,scriptHandle)

    -- ==============================================================
    -- COMPONENTS
    -- ==============================================================

    self.vehicleName = self.objName
    self.vehicleRefHandle = api.simGetChildObjectHandle(self.objHandle, 'rearAxleRef')
    self.steering = api.simGetChildObjectHandle(self.objHandle, 'steering')
    self.steeringWheel = api.simGetChildObjectHandle(self.objHandle, 'steeringWheelJoint')

    self.axle1LeftSteering = api.simGetChildObjectHandle(self.objHandle, 'axle1LeftSteering')
    self.axle1RightSteering = api.simGetChildObjectHandle(self.objHandle, 'axle1RightSteering')

    self.axle1Left = api.simGetChildObjectHandle(self.objHandle, 'axle1LeftMotor')
    self.axle1Right = api.simGetChildObjectHandle(self.objHandle, 'axle1RightMotor')
    self.axle2Left = api.simGetChildObjectHandle(self.objHandle, 'axle2LeftMotor')
    self.axle2Right = api.simGetChildObjectHandle(self.objHandle, 'axle2RightMotor')

    -- ==============================================================
    -- MODEL PROPERTIES
    -- ==============================================================
    self.d=0.755 -- 2*d=distance between left and right wheels
    self.l=2.5772 -- l=distance between front and read wheels
    self.d1=self.d
    self.d2=self.d
    self.d=(self.d1+self.d2)/2 -- d=0.933 -- 2*d=distance between left and right wheels
    self.wheelRadius=1.7175

    self.steeringRatio=simGetScriptSimulationParameter(self.scriptHandle, 'steeringRatio')

    self.maxSteeringAngle = loadstring("return " ..
        simGetScriptSimulationParameter(self.scriptHandle, 'maxSteeringAngle', true)
    )() -- Allows specifying expressions like "36*math.pi/180"
    self.maxSpeed = simGetScriptSimulationParameter(self.scriptHandle, 'maxSpeed')
    self.maxSpeedReverse = simGetScriptSimulationParameter(self.scriptHandle, 'maxSpeedReverse')
    self.maxMotorTorque = simGetScriptSimulationParameter(self.scriptHandle, 'maxMotorTorque')
    self.maxServiceBrakeTorque = simGetScriptSimulationParameter(self.scriptHandle, 'maxServiceBrakeTorque')
    self.maxParkingBrakeTorque = simGetScriptSimulationParameter(self.scriptHandle, 'maxParkingBrakeTorque')
    
    self.refSteeringAngleDefault=0.0
    self.refGearDefault = 0;
    self.refSpeedDefault = 0;
    self.refMotorTorqueDefault = simGetScriptSimulationParameter(self.scriptHandle, 'defaultMotorTorque')
    self.refServiceBrakeTorqueDefault = 0.0;
    self.refParkingBrakeTorqueDefault = 0.0;
    self.defaultIdleMotorTorque = simGetScriptSimulationParameter(self.scriptHandle, 'defaultIdleMotorTorque')

    -- ==============================================================
    -- SIGNALS DEFINITIONS
    -- ==============================================================

    self.refSteeringAngleSignalName = api.getSignalName(self.vehicleName, 'RefSteeringAngle')
    self.refGearSignalName = api.getSignalName(self.vehicleName, 'RefGear')
    self.refSpeedSignalName = api.getSignalName(self.vehicleName, 'RefSpeed')
    self.refMotorTorqueSignalName = api.getSignalName(self.vehicleName, 'RefMotorTorque')
    self.refServiceBrakeTorqueSignalName = api.getSignalName(self.vehicleName, 'RefServiceBrakeTorque')
    self.refParkingBrakeTorqueSignalName = api.getSignalName(self.vehicleName, 'RefParkingBrakeTorque')

    self.manualRefSteeringAngleSignalName = api.getSignalName(self.vehicleName, 'ManualRefSteeringAngle')
    self.manualRefGearSignalName = api.getSignalName(self.vehicleName, 'ManualRefGear')
    self.manualRefSpeedSignalName = api.getSignalName(self.vehicleName, 'ManualRefSpeed')
    self.manualRefMotorTorqueSignalName = api.getSignalName(self.vehicleName, 'ManualRefMotorTorque')
    self.manualRefServiceBrakeTorqueSignalName = api.getSignalName(self.vehicleName, 'ManualRefServiceBrakeTorque')
    self.manualRefParkingBrakeTorqueSignalName = api.getSignalName(self.vehicleName, 'ManualRefParkingBrakeTorque')

    self.currentSteeringAngleSignalName = api.getSignalName(self.vehicleName, 'currentSteeringAngle')
    self.currentSteeringWheelAngleSignalName = api.getSignalName(self.vehicleName, 'currentSteeringWheelAngle')
    self.currentPoseSignalName = api.getSignalName(self.vehicleName, 'currentPose')
    self.currentTwistSignalName = api.getSignalName(self.vehicleName, 'currentTwist')
    self.currentSpeedSignalName = api.getSignalName(self.vehicleName, 'currentSpeed')
    self.currentGearSignalName = api.getSignalName(self.vehicleName, 'currentGear')
    self.currentWheelSpeedSignalName = api.getSignalName(self.vehicleName, 'currentWheelSpeed')

    self.autoModeReqSignalName = api.getSignalName(self.vehicleName, 'AutoModeRequest')
    self.autoModeSignalName = api.getSignalName(self.vehicleName, 'AutoMode')

    self.manualControlSourceIdSignalName = api.getSignalName(self.vehicleName, 'ManualControlSourceId')
end)

function Vehicle:initialization()
    ChildScriptBase.initialization(self)
    -- self:log("initialization")

    self.autoMode = Vehicle.MODE_MANUAL
    self.driverOverride = Vehicle.DRIVER_OVERRIDE_INACTIVE
    self.currentGear = Vehicle.GEAR_NEUTRAL
    self.steering_on_auto_mode_request = nil
    self.steering_driver_override_threshold = 0.05

    simSetObjectInt32Parameter(self.axle1Left,2000,0)    -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)
    simSetObjectInt32Parameter(self.axle1Right,2000,0)   -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)
    simSetObjectInt32Parameter(self.axle2Left,2000,0)    -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)
    simSetObjectInt32Parameter(self.axle2Right,2000,0)   -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)

    -- Runs sensing once so values are available in the first actuation phase
    self:sensing()
end

function Vehicle:actuation()
    -- self:log("actuation")

    -- ==============================================================
    -- READ MANUAL SIGNALS
    -- ==============================================================
    self.autoModeReq=api.saturate(
        simGetIntegerSignal(self.autoModeReqSignalName),
        Vehicle.MODE_MANUAL, Vehicle.MODE_AUTO_SPEED_ONLY, Vehicle.MODE_MANUAL
    )
    --simAddStatusbarMessage(string.format("Auto mode request: %d", autoModeReq))

    -- Manual commands

    self.refSteeringAngle = api.saturate(
        simGetFloatSignal(self.manualRefSteeringAngleSignalName),
        -self.maxSteeringAngle, self.maxSteeringAngle, self.refSteeringAngleDefault
    )
    
    self.refSpeed = api.saturate(
        simGetFloatSignal(self.manualRefSpeedSignalName),
        0, self.maxSpeed, self.refSpeedDefault
    )

    self.refMotorTorque = api.saturate(
        simGetFloatSignal(self.manualRefMotorTorqueSignalName),
        0, self.maxMotorTorque, self.refMotorTorqueDefault
    )

    self.currentGear = api.saturate(
        simGetIntegerSignal(self.manualRefGearSignalName),
        Vehicle.GEAR_NEUTRAL, Vehicle.GEAR_REVERSE, self.refGearDefault
    )

    self.refServiceBrakeTorque = api.saturate(
        simGetFloatSignal(self.manualRefServiceBrakeTorqueSignalName),
        0, self.maxServiceBrakeTorque, self.refServiceBrakeTorqueDefault
    )

    self.refParkingBrakeTorque = api.saturate(
        simGetFloatSignal(self.manualRefParkingBrakeTorqueSignalName),
        0, self.maxParkingBrakeTorque, self.refParkingBrakeTorqueDefault
    )

    -- ==============================================================
    -- DRIVER OVERRIDE RULES
    -- ==============================================================

    -- Insert driver override rules here
    self.previousDriverOverride = self.driverOverride
    self.previousAutoMode = self.autoMode

    if( self.currentGear == Vehicle.GEAR_NEUTRAL
        --and refSpeed < EPSILON
        --and refServiceBrakeTorque < EPSILON
        --and refParkingBrakeTorque > 0
    ) then
        self.driverOverride = Vehicle.DRIVER_OVERRIDE_INACTIVE
    end

    if( (self.autoMode == Vehicle.MODE_AUTO or self.autoMode == Vehicle.MODE_AUTO_SPEED_ONLY )
        and (
            self.currentGear > Vehicle.GEAR_NEUTRAL
            --or refSpeed > EPSILON        
            --or refServiceBrakeTorque > 0
            --or refParkingBrakeTorque < 1
        )
    ) then
        self.driverOverride = Vehicle.DRIVER_OVERRIDE_SPEED
    end

    if( (self.autoMode == Vehicle.MODE_AUTO or self.autoMode == Vehicle.MODE_AUTO_STEERING_ONLY )
        and self.steering_on_auto_mode_request ~= nil 
        and math.abs(self.steering_on_auto_mode_request - self.refSteeringAngle) > self.steering_driver_override_threshold 
    ) then
        self.driverOverride = Vehicle.DRIVER_OVERRIDE_STEERING
        self.steering_on_auto_mode_request = nil
    end

    -- ==============================================================
    -- INTERPRET DRIVER OVERRIDE
    -- ==============================================================

    if( (self.autoModeReq == Vehicle.MODE_AUTO and self.driverOverride > 0) 
        or (self.autoModeReq == Vehicle.MODE_AUTO_SPEED_ONLY and self.driverOverride == Vehicle.DRIVER_OVERRIDE_SPEED) 
        or (self.autoModeReq == Vehicle.MODE_AUTO_STEERING_ONLY and self.driverOverride == Vehicle.DRIVER_OVERRIDE_STEERING) 
    ) then
        self.autoMode = Vehicle.MODE_MANUAL
    else
        self.autoMode = self.autoModeReq
    end

    if(self.previousDriverOverride ~= self.driverOverride) then
        if(self.driverOverride > 0) then
            simAddStatusbarMessage(string.format("Driver override (%s).", Vehicle.driverOverride2str(self.driverOverride)) )
        else
            simAddStatusbarMessage("Driver override ended.")
        end
    end
    if(self.previousAutoMode ~= self.autoMode) then
        simAddStatusbarMessage(string.format("Entered %s mode.", Vehicle.mode2str(self.autoMode)))

        if(self.autoMode > Vehicle.MODE_MANUAL) then
            self.steering_on_auto_mode_request = self.refSteeringAngle
        end
    end
    
    -- ==============================================================
    -- READ AUTO SIGNALS
    -- ==============================================================

    if(self.autoMode == Vehicle.MODE_AUTO or self.autoMode == Vehicle.MODE_AUTO_STEERING_ONLY) then
        self.refSteeringAngle = api.saturate(
            simGetFloatSignal(self.refSteeringAngleSignalName),
            -self.maxSteeringAngle, self.maxSteeringAngle, self.refSteeringAngleDefault
        )
    end    

    if(self.autoMode == Vehicle.MODE_AUTO or autoMode == Vehicle.MODE_AUTO_SPEED_ONLY) then
        self.refSpeed = api.saturate(
            simGetFloatSignal(self.refSpeedSignalName),
            0, self.maxSpeed, self.refSpeedDefault
        )

        self.refMotorTorque = api.saturate(
            simGetFloatSignal(self.refMotorTorqueSignalName),
            0, self.maxMotorTorque, self.refMotorTorqueDefault
        )

        self.refGear = api.saturate(
            simGetIntegerSignal(self.refGearSignalName),
            GEAR_NEUTRAL,GEAR_REVERSE, self.refGearDefault
        )

        self.refServiceBrakeTorque = self.api.saturate(
            simGetFloatSignal(self.refServiceBrakeTorqueSignalName),
            0, self.maxServiceBrakeTorque, self.refServiceBrakeTorqueDefault
        )

        self.refParkingBrakeTorque = api.saturate(
            simGetFloatSignal(self.refParkingBrakeTorqueSignalName),
            0, self.maxParkingBrakeTorque, self.refParkingBrakeTorqueDefault
        )
    end

    -- ==============================================================
    -- STEERING ANGLE
    -- ==============================================================
    
    -- -- Following is a dummy joint, that represents the ref steering angle:
    simSetJointPosition(self.steering, self.refSteeringAngle)    
    -- In what follows we always read the ref steering angle from that dummy joint.
    self.steeringAngle = simGetJointPosition(self.steering)    
    -- We handle the steering wheel:
    self.steeringWheelAngle = self.steeringAngle*self.steeringRatio
    simSetJointPosition(self.steeringWheel, self.steeringWheelAngle)
    self.steeringAngle = self.refSteeringAngle
    
    -- We handle the front left and right wheel steerings (Ackermann steering):   
    phi_axle1Left=math.atan( (math.tan(self.steeringAngle)*self.l) / (self.l-self.d1*math.tan(self.steeringAngle)) )  
    phi_axle1Right=math.atan( (math.tan(self.steeringAngle)*self.l) / (self.l+self.d1*math.tan(self.steeringAngle)) )  

    simSetJointTargetPosition(self.axle1LeftSteering, phi_axle1Left)
    simSetJointTargetPosition(self.axle1RightSteering, phi_axle1Right)   

    -- ==============================================================
    -- SPEED
    -- ==============================================================  
    linearVelocity,angularVelocity=simGetObjectVelocity(self.vehicleRefHandle)
    self.currentSpeed = math.sqrt(linearVelocity[1]^2, linearVelocity[2]^2, linearVelocity[3]^2)

    if(self.currentGear == Vehicle.GEAR_NEUTRAL) then
        self.refSpeed = 0; 
    elseif(self.currentGear == Vehicle.GEAR_REVERSE) then
        self.refSpeed = api.saturate(
            self.refSpeed,
            0, self.maxSpeedReverse, self.refSpeedDefault
        )
        self.refSpeed = -self.refSpeed; 
    end

    axle1Left_enable = 0
    axle1Right_enable = 0
    axle2Left_enable = 1
    axle2Right_enable = 1

    wref_axle1Left = self.refSpeed*(1/self.wheelRadius)
    wref_axle1Right = self.refSpeed*(1/self.wheelRadius)
    wref_axle2Left = ((self.l-self.d2*math.tan(self.steeringAngle))/self.l)*self.refSpeed*(1/self.wheelRadius)
    wref_axle2Right = ((self.l+self.d2*math.tan(self.steeringAngle))/self.l)*self.refSpeed*(1/self.wheelRadius)

    if(self.refSpeed == 0.0 or math.abs(self.refSpeed) < self.currentSpeed) then
        wheelTorque = self.defaultIdleMotorTorque
    else
        wheelTorque = self.refMotorTorque
    end

    -- ==============================================================
    -- BRAKES
    -- ==============================================================  

    if(self.refServiceBrakeTorque > 0 or self.refParkingBrakeTorque > 0) then
        axle1Left_enable = 1
        axle1Right_enable = 1
        axle2Left_enable = 1
        axle2Right_enable = 1

        wref_axle1Left = 0
        wref_axle1Right = 0
        wref_axle2Left = 0
        wref_axle2Right = 0

        wheelTorque = self.refServiceBrakeTorque + self.refParkingBrakeTorque
    end

    -- ==============================================================
    -- WHEEL ACTUATION
    -- ==============================================================  

    simSetObjectInt32Parameter(self.axle1Left,2000,axle1Left_enable)    -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)
    simSetObjectInt32Parameter(self.axle1Right,2000,axle1Right_enable)   -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)
    simSetObjectInt32Parameter(self.axle2Left,2000,axle2Left_enable)    -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)
    simSetObjectInt32Parameter(self.axle2Right,2000,axle2Right_enable)   -- sim_jointintparam_motor_enabled (2000): int32 parameter : dynamic motor enable state (0 or !=0)

    simSetJointTargetVelocity(self.axle1Left,wref_axle1Left)
    simSetJointTargetVelocity(self.axle1Right,wref_axle1Right)
    simSetJointTargetVelocity(self.axle2Left,wref_axle2Left)
    simSetJointTargetVelocity(self.axle2Right,wref_axle2Right)

    simSetJointForce(self.axle1Left,wheelTorque)
    simSetJointForce(self.axle1Right,wheelTorque)
    simSetJointForce(self.axle2Left,wheelTorque)
    simSetJointForce(self.axle2Right,wheelTorque)
end

function Vehicle:sensing()
    -- self:log("sensing")

    self.currentSteeringAngle=simGetJointPosition(self.steering)  
    self.currentSteeringWheelAngle=self.currentSteeringAngle*self.steeringRatio  

    pos=simGetObjectPosition(self.vehicleRefHandle,-1)
    ori=simGetObjectOrientation(self.vehicleRefHandle,-1)
    poseData=simPackFloats({pos[1],pos[2],pos[3],ori[1],ori[2],ori[3]})

    vel,w= simGetObjectVelocity(self.vehicleRefHandle,-1)
    velData=simPackFloats(vel)
    speed = math.sqrt(vel[1]*vel[1]+vel[2]*vel[2]+vel[3]*vel[3])

    H_T1=simGetObjectMatrix(self.vehicleRefHandle,-1)
    q_T1 = simGetQuaternionFromMatrix(H_T1)
    R_T1 = simBuildMatrixQ({0,0,0}, q_T1)
    R_T1_inv = simGetInvertedMatrix(R_T1)
    v_T1 = simMultiplyVector(R_T1_inv, vel)
    w_T1 = simMultiplyVector(R_T1_inv, w)
    twist={v_T1[1],v_T1[2],v_T1[3],w_T1[1],w_T1[2],w_T1[3]}
    twistData=simPackFloats(twist)  

    simSetFloatSignal(self.currentSteeringAngleSignalName,self.currentSteeringAngle)
    simSetFloatSignal(self.currentSteeringWheelAngleSignalName,self.currentSteeringWheelAngle)
    simSetStringSignal(self.currentPoseSignalName,poseData)
    simSetStringSignal(self.currentTwistSignalName,twistData)
    simSetFloatSignal(self.currentSpeedSignalName,speed)
    simSetIntegerSignal(self.currentGearSignalName, self.currentGear)
    simSetFloatSignal(self.currentWheelSpeedSignalName,0)
    simSetIntegerSignal(self.autoModeSignalName,self.autoMode)
end

function Vehicle:cleanup()
    -- self:log("cleanup")

    simClearFloatSignal(self.refSteeringAngleSignalName)
    simClearIntegerSignal(self.refGearSignalName)
    simClearStringSignal(self.refSpeedSignalName)
    simClearStringSignal(self.refMotorTorqueSignalName)
    simClearFloatSignal(self.refServiceBrakeTorqueSignalName)
    simClearFloatSignal(self.refParkingBrakeTorqueSignalName)

    simClearFloatSignal(self.manualRefSteeringAngleSignalName)
    simClearIntegerSignal(self.manualRefGearSignalName)
    simClearStringSignal(self.manualRefSpeedSignalName)
    simClearStringSignal(self.manualRefMotorTorqueSignalName)
    simClearFloatSignal(self.manualRefServiceBrakeTorqueSignalName)
    simClearFloatSignal(self.manualRefParkingBrakeTorqueSignalName)

    simClearIntegerSignal(self.autoModeReqSignalName)

end

function Vehicle:isManualControlSource(manualControlSourceId)
    id = simGetStringSignal(self.manualControlSourceIdSignalName)
    if(id == nil) then
        return false;
    end

    return id == manualControlSourceId
end

function Vehicle:setManualControlSource(manualControlSourceId)
    if(self:isManualControlSource()) then
        return
    end

    simSetStringSignal(self.manualControlSourceIdSignalName, manualControlSourceId)

    self:log("Manual control source set to " .. manualControlSourceId)
end


-- ==============================================================
-- CONSTANTS
-- ==============================================================
Vehicle.MODE_MANUAL = 0
Vehicle.MODE_AUTO = 1
Vehicle.MODE_AUTO_STEERING_ONLY = 2
Vehicle.MODE_AUTO_SPEED_ONLY = 3

Vehicle.DRIVER_OVERRIDE_INACTIVE = 0
Vehicle.DRIVER_OVERRIDE_STEERING = 1
Vehicle.DRIVER_OVERRIDE_SPEED = 2

Vehicle.GEAR_NEUTRAL = 0
Vehicle.GEAR_FORWARD = 1
Vehicle.GEAR_REVERSE = 2

Vehicle.EPSILON = 0.01

-- ==============================================================
-- STATIC
-- ==============================================================
function Vehicle.mode2str(mode)
    if(mode == Vehicle.MODE_MANUAL) then
        return "MANUAL"
    end
    if(mode == Vehicle.MODE_AUTO) then
        return "AUTO"
    end
    if(mode == Vehicle.MODE_AUTO_STEERING_ONLY) then
        return "AUTO_STEERING_ONLY"
    end
    if(mode == Vehicle.MODE_AUTO_SPEED_ONLY) then
        return "AUTO_SPEED_ONLY"
    end
    return "UNKNOWN"
end

function Vehicle.driverOverride2str(driverOverride)
    if(driverOverride == Vehicle.DRIVER_OVERRIDE_INACTIVE) then
        return "NOT_ACTIVE"
    end
    if(driverOverride == Vehicle.DRIVER_OVERRIDE_STEERING) then
        return "MANUAL_STEERING_CONTROL"
    end
    if(driverOverride == Vehicle.DRIVER_OVERRIDE_SPEED) then
        return "MANUAL_SPEED_CONTROL"
    end
    return "UNKNOWN"
end


return Vehicle

