local Validator, Exception = require"Validators.Validator", require"Exception"
local type, tostring, dump = type, tostring, dump

module(...)

local Length = Validator:extend{
	init = function (self, minOrMaxLength, maxLength)
		if not minOrMaxLength or type(minOrMaxLength) ~= "number" then
			Exception:new"maxLength required!":throw()
		end
		if maxLength then
			self.maxLength = maxLength
			self.minLength = minOrMaxLength
		else
			self.maxLength = minOrMaxLength
		end
	end,
	validate = function (self, value)
		if type(value) == "number" then
			value = tostring(value)
		elseif type(value) ~= "string" then
			value = ""
		end
		if #value > self.maxLength or (self.minLength and #value < self.minLength) then
			return false
		end
		return true
	end
}

return Length