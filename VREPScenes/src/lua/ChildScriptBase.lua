require 'class'

local ChildScriptBase = class(function(self,scriptHandle)
    -- simAddStatusbarMessage("ChildScriptBase ctor")

    self.scriptHandle = scriptHandle
    self.objHandle= simGetObjectAssociatedWithScript(self.scriptHandle)
    self.objName = simGetObjectName(self.objHandle);
end)

function ChildScriptBase:log(message)
	simAddStatusbarMessage(self.objName .. ": " .. message)
end

function ChildScriptBase:execute()
	-- self:log("execute")

	if(simGetScriptExecutionCount() == 0) then
		self:firstExecution()
	end

	if (sim_call_type==sim_childscriptcall_initialization) then
		self:initialization()
	end

	if (sim_call_type==sim_childscriptcall_actuation) then
		self:actuation()
	end

	if (sim_call_type==sim_childscriptcall_sensing) then
		self:sensing()
	end

	if (sim_call_type==sim_childscriptcall_cleanup) then
		self:cleanup()
	end
end

function ChildScriptBase:firstExecution()
	-- self:log("firstExecution")
end

function ChildScriptBase:initialization()
	-- self:log("initialization")
end

function ChildScriptBase:actuation()
	-- self:log("actuation")
end

function ChildScriptBase:sensing()
	-- self:log("sensing")
end

function ChildScriptBase:cleanup()
	-- self:log("cleanup")
end




return ChildScriptBase