local Validator = require"Validators.Validator"
local string, tostring = string, tostring

module(...)

local Regexp = Validator:extend{
	__tag = "Validators.Regexp",
	
	init = function (self, regexp)
		self.regexp = regexp
	end,
	validate = function (self, value)
		if not string.find(tostring(value), self.regexp) then
			return false
		end
		return true
	end
}

return Regexp