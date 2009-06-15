local table = require"luv.table"
require "luv.checktypes"
local tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset, expect, checkTypes, _G = tostring, getmetatable, setmetatable, error, io, debug, type, pairs, rawget, rawset, expect, checkTypes, _G

module(...)

local expect = expect
_G.expect = function (value, valType)
	if type(valType) == "string" then
		return expect(value, valType)
	elseif type(value) == "table" and value.isObject and value:isKindOf(valType) then
		return true
	else
		error("Given object has not expected type! "..debug.traceback())
	end
end

local clone = function (obj, tbl)
	tbl = tbl or {}
	tbl.parent = obj
	local mt = getmetatable(obj)
	if not mt then
		mt = {__index = obj, __call = function (obj, ...) return obj:new(...) end}
	else
		mt = table.copy(mt)
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

local abstractMethod = function () error("Method must be implemented first! "..debug.traceback()) end

local Object = {
	__tag = .....".Object",
	isObject = true,
	init = abstractMethod,
	extend = function (self, tbl)
		return clone(self, tbl)
	end,
	new = function (self, ...)
		local obj = clone(self, {})
		obj:init(...)
		rawset(obj, "new", self.maskedMethod)
		return obj
	end,
	clone = function (self)
		local new = table.copy(self)
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
	maskedMethod = function () error("Masked method! "..debug.traceback()) end,
	checkTypes = checkTypes,
	singleton = function (self) return self end
}

return {Object=Object}
