local Object, Debug, Exception = require"ProtOo", require"Debug", require"Exception"
local getmetatable, setmetatable, rawget, rawset, io, pairs, dump, debug = getmetatable, setmetatable, rawget, rawset, io, pairs, dump, debug

module(...)

local get = function (self, field)
	local res = rawget(self, "parent")[field]
	if res then return res end
	res = self:getField(field)
	if not res then
		return nil
	end
	return res:getValue()
end

local set = function (self, field, value)
	local res = self:getField(field)
	if res then
		res:setValue(value)
	else
		rawset(self, field, value)
	end
	return value
end

local Struct = Object:extend{
	__tag = "Struct",

	new = function (self)
		local obj = Object.new(self)
		setmetatable(obj, { __index = get, __newindex = set })
		return obj
	end,
	validate = function (self)
		local k, v
		for k, v in pairs(self.fields) do
			if not v:validate() then
				return false
			end
		end
		return true
	end,
	getField = function (self, field)
		local _, v
		for _, v in pairs(self.fields) do
			if v:getName() == field then
				return v
			end
		end
		return nil
	end
}

return Struct
