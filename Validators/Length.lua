local Validator, Exception = require"Validators.Validator", require"Exception"
local type, tostring, dump = type, tostring, dump

module(...)

return Validator:extend{
	__tag = "Validators.Length",
	
	init = function (self, minLength, maxLength)
		self.minLength = minLength
		self.maxLength = maxLength
	end,
	getMaxLength = function (self) return self.maxLength end,
	getMinLength = function (self) return self.minLength end,
	validate = function (self, value)
		if type(value) == "number" then
			value = tostring(value)
		elseif type(value) ~= "string" then
			value = ""
		end
		if (self.maxLength ~= 0 and #value > self.maxLength) or (self.minLength and #value < self.minLength) then
			return false
		end
		return true
	end
}
