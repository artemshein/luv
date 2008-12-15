local CheckTypes, Debug = require"CheckTypes", require"Debug"
local tostring, setmetatable, error, io, debug, type = tostring, setmetatable, error, io, debug, type

module(...)

CheckTypes.oldExpect = CheckTypes.expect
CheckTypes.expect = function (value, valType)
	if type(valType) == "string" then
		return CheckTypes.oldExpect(value, valType)
	elseif type(value) == "table" and value:isKindOf(valType) then
		return true
	else
		error("Given object has not expected type! "..debug.traceback())
	end
end

local abstractMethod = function ()
	error("Method must be implemented first! "..debug.traceback())
end

local Object = {
	__tag = "Object",
	init = abstractMethod,
	extend = function (self, tbl)
		local newObj = tbl or {}
		newObj.parent = self
		setmetatable(newObj, { __index = self })
		return newObj
	end,
	new = function (self, ...)
		local newObj = {}
		newObj.parent = self
		setmetatable(newObj, { __index = self })
		newObj:init(...)
		return newObj
	end,
	isKindOf = function (self, obj)
		if obj and (self == obj or (self.parent and (self.parent):isKindOf(obj))) then
			return true
		end
		return false
	end,
	abstractMethod = abstractMethod,
	checkTypes = CheckTypes.checkTypes
}

return Object