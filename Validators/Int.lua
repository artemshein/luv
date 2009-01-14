local Validator = require"Validators.Validator"
local type, tonumber, Debug = type, tonumber, require"Debug"

module(...)

return Validator:extend{
	__tag = "Validators.Int",
	
	init = function (self) return self end,
	validate = function (self, value)
		if value == nil then
			return true
		end
		if type(value) == "number" then
			return true
		elseif type(value) == "string" then
			return nil ~= tonumber(value)
		end
		return false
	end
}
