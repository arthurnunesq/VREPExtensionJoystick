require 'class'
api = require('api')
ChildScriptBase = require('ChildScriptBase')

local ModelComponentScriptBase = class(ChildScriptBase, function(self,scriptHandle)
    -- simAddStatusbarMessage("ModelComponentScriptBase ctor")

    ChildScriptBase.init(self,scriptHandle)

    self.modelHandle = api.getParentModelHandler(self.objHandle)
    self.modelName = simGetObjectName(self.modelHandle);
    self.modelScriptHandle = simGetScriptAssociatedWithObject(self.modelHandle)
end)


return ModelComponentScriptBase
