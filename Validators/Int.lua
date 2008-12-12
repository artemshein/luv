local Validator = require"Validators.Validator"
local type, tonumber = type, tonumber

module(...)

local Int = Validator:extend{
	init = function (self) return self end,
	validate = function (self, value)
		if type(value) == "number" then
			return true
		elseif type(value) == "string" then
			return nil ~= tonumber(value)
		end
		return false
	end
}

return Int