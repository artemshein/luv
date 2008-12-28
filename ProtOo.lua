local Table, CheckTypes, Debug = require"Table", require"CheckTypes", require"Debug"
local tostring, getmetatable, setmetatable, error, io, debug, type = tostring, getmetatable, setmetatable, error, io, debug, type

module(...)

local expect = CheckTypes.expect
CheckTypes.expect = function (value, valType)
	if type(valType) == "string" then
		return expect(value, valType)
	elseif type(value) == "table" and value:isKindOf(valType) then
		return true
	else
		error("Given object has not expected type! "..debug.traceback())
	end
end

local abstractMethod = function ()
	error("Method must be implemented first! "..debug.traceback())
end

local maskedMethod = function ()
	error("Method not founded! "..debug.traceback())
end

local singleton = function (self) return self end

local clone = function (obj, tbl)
	tbl = tbl or {}
	tbl.parent = obj
	local mt = getmetatable(obj)
	if not mt then
		mt = {}
	else
		mt = Table.copy(mt)
	end
	mt.__index = obj
	setmetatable(tbl, mt)
	return tbl
end

local Object = {
	__tag = "Object",
	init = abstractMethod,
	extend = function (self, tbl)
		return clone(self, tbl)
	end,
	new = function (self, ...)
		local obj = clone(self, {})
		obj:init(...)
		return obj
	end,
	isKindOf = function (self, obj)
		if obj and (self == obj or (self.parent and (self.parent):isKindOf(obj))) then
			return true
		end
		return false
	end,
	abstractMethod = abstractMethod,
	maskedMethod = maskedMethod,
	checkTypes = CheckTypes.checkTypes
}

return Object