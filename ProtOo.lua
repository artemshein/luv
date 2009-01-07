local Table, CheckTypes, Debug = require"Table", require"CheckTypes", require"Debug"
local tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset = tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset

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
		mt = {__index = obj}
	else
		mt = Table.copy(mt)
	end
	if type(mt.__index) == "table" then
		mt.__index = obj
	end
	-- Move magic methods to metatable
	local magicMethods, _, v = {"__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat", "__len", "__eq", "__lt", "__le", "__index", "__newindex", "__call", "__tostring"}
	for _, v in pairs(magicMethods) do
		local method = rawget(tbl, v)
		if method then
			rawset(mt, v, method)
			rawset(tbl, v, nil)
		end
	end
	setmetatable(tbl, mt)
	return tbl
end

return {
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
	clone = function (self)
		local new = Table.copy(self)
		setmetatable(new, getmetatable(self))
		return new
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
