-- http://www.forum.coppeliarobotics.com/viewtopic.php?f=9&t=183&p=541&hilit=outside#p541
-- http://www.forum.coppeliarobotics.com/viewtopic.php?f=9&t=781
-- http://www.forum.coppeliarobotics.com/viewtopic.php?f=9&t=905
-- http://stackoverflow.com/a/12191225/702828
-- http://stackoverflow.com/questions/4394303/how-to-make-namespace-in-lua
-- http://hisham.hm/2014/01/02/how-to-write-lua-modules-in-a-post-module-world/

-- To include this library in a VREP child script, copy the code below to the 
-- sim_childscriptcall_initialization if definition.
    -- srcdir = string.match(simGetStringParameter(sim_stringparam_scene_path_and_name), "(.-)([^\\/]-%.?([^%.\\/]*))$") .. "../src/lua/"
    -- package.path = package.path .. ";" 
    -- package.path = package.path .. (srcdir .. "?.lua;")
    -- api = require("api")

--- @module api
local api = {}

-- http://stackoverflow.com/a/19667498/702828
function api.isempty(s)
  return s == nil or s == ''
end

-- http://stackoverflow.com/a/15278426/702828
function api.concat(t1,t2)
    for i=1,#t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end

function api.getParentModelHandler(objHandler)
    local parent = simGetObjectParent(objHandler)
    while (parent > -1) do
        if( simBoolAnd32(simGetModelProperty(parent), sim_modelproperty_not_model)
            ==sim_modelproperty_not_model)then
            parent = simGetObjectParent(parent)
        else
            return parent
        end        
    end
    return -1
end

function api.simGetObjectsInTree(treeBaseHandle)
	local objTree = {treeBaseHandle}

	local i = 0
	local childHandle = simGetObjectChild(treeBaseHandle, i)
	while childHandle > -1 do
		local offspring = api.simGetObjectsInTree(childHandle)
		objTree = api.concat(objTree, offspring)

		i = i + 1
		childHandle = simGetObjectChild(treeBaseHandle, i)
	end

    return objTree
end

function api.simGetObjectNameInfo(objName)
    local objNameSufixNumber = simGetNameSuffix(objName)

    local objNameWithoutSufix = ""
    local objNameSufix = ""

    if (objNameSufixNumber > -1) then
        objNameSufix = "#" .. tostring(objNameSufixNumber) 
        objNameWithoutSufix = string.gsub(objName, objNameSufix, "")
    else
        objNameWithoutSufix = objName
    end

    return objName, objNameWithoutSufix, objNameSufix, objNameSufixNumber
end

function api.simGetObjectName(objHandle)
    local objName = simGetObjectName(objHandle);

    return api.simGetObjectNameInfo(objName)
end

function api.simGetChildObjectHandle(objHandle, childObjName)
    local objName = simGetObjectName(objHandle);
    local objNameSufixNumber = simGetNameSuffix(objName)

    local objNameSufix = ""
    if (objNameSufixNumber > -1) then
        objNameSufix = "#" .. objNameSufixNumber
        objNameWithoutSufix = string.gsub(objName, objNameSufix, "")
    else
        objNameWithoutSufix = objName
    end

    local childObjFullName = objNameWithoutSufix .. "_" .. childObjName .. objNameSufix

    return simGetObjectHandle(childObjFullName)
end

function api.getSignalName(objName, signalName)
    return objName .. "_" .. signalName
end

function api.saturate(a, amin, amax, adefault)
    if(a == nil) then
        return adefault
    end

    if(adefault == nil) then
        adefault = 0.0
    end

    if( not(amin <= a and a <= amax) ) then 
        if(a < amin) then    
            a = amin
        elseif(amax < a) then 
            a = amax
        else    -- Handle situations where NAN is returned when the controller is in the deadzone
            a = adefault
        end
    end
    return a
end

function api.applySensibility(I,s)
    -- https://github.com/achilleas-k/fs2open.github.com/blob/joystick_curves/joy_curve_notes/new_curves.md#existing-curves
    s = s*9
    Is = I*(s/9)+(I^5)*(9-s)/9;
    return Is;
end

function api.renameModelTree(modelHandler, targetName, print_only)
    local targetName, targetNameWithoutSuffix, targetNameSufix = api.simGetObjectNameInfo(targetName);

    local modelName, modelNameWithoutSuffix, modelNameSufix = api.simGetObjectName(modelHandler);

    if(modelName == targetName) then
        return
    end

    local descendants = api.simGetObjectsInTree(modelHandler)
    for i, descendant in ipairs(descendants) do 
        local name = simGetObjectName(descendant);
        local newName, ns = string.gsub(name, modelNameWithoutSuffix, targetNameWithoutSuffix)

        if(ns == 0) then -- If the child's name does not have the model name prefix, then append it.
        	newName = targetNameWithoutSuffix .. "_" .. name
        end

        if(not api.isempty(modelNameSufix))then 
            newName = string.gsub(newName, modelNameSufix, "")
        end

        newName = newName .. targetNameSufix

        simAddStatusbarMessage("Renaming " .. name .. " to " .. newName)

        if(not print_only) then
            simSetObjectName(descendant, newName)
        end
    end
end

return api