local Object, Debug, Exception = require"ProtOo", require"Debug", require"Exception"
local getmetatable, setmetatable, rawget, rawset, io, pairs, dump, debug = getmetatable, setmetatable, rawget, rawset, io, pairs, dump, debug

module(...)

return Object:extend{
	__tag = "Struct",

	__index = function (self, field)
		local res = rawget(self, "fields")
		if res then
			res = res[field]
			if res then
				return res:getValue()
			end
		end
		return rawget(self, "parent")[field]
	end,
	__newindex = function (self, field, value)
		local res = self:getField(field)
		if res then
			res:setValue(value)
		else
			rawset(self, field, value)
		end
		return value
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
		if not self.fields then
			Exception:new"Fields must be defined first!":throw()
		end
		return self.fields[field]
	end
}
