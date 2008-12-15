local Validator = require"Validators.Validator"
local type = type

module(...)

local Filled = Validator:extend{
	__tag = "Validators.Filled",
	
	init = function (self) return self end,
	validate = function (self, value)
		if type(value) == "string" then
			return 0 ~= #value
		elseif type(value) ~= "nil" then
			return true
		end
		return false
	end
}

return Filled