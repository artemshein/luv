local Object, Debug, Exception = require"ProtOo", require"Debug", require"Exception"
local getmetatable, setmetatable, rawget, io, pairs, dump, debug = getmetatable, setmetatable, rawget, io, pairs, dump, debug

module(...)

local get = function (self, field)
	local res = rawget(self, "parent")[field]
	if res then return res end
	res = rawget(self, "fields")
	if not res or not res[field] then
		return nil
	end
	return res[field]:getValue()
end

local set = function (self, field, value)
	local res = self.fields[field]
	if res then
		res:setValue(value)
	else
		rawset(self, field, value)
	end
	return value
end

local Struct = Object:extend{
	__tag = "Struct",
	init = Object.abstractMethod,
	--[[extend = function (self, tbl)
		local newObj = Object.extend(self, tbl)
		setmetatable(newObj, { __index = get, __newindex = set })
		return newObj
	end,]]
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
		return self.fields[field]
	end
}

return Struct