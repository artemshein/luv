local Validator = require"Validators.Validator"
local type, tostring, tonumber = type, tostring, tonumber

module(...)

return Validator:extend{
	__tag = "Validators.Value",
	
	init = function (self, value)
		self.value = value
	end,
	validate = function (self, value)
		if self.value == value then
			return true
		elseif type(self.value) == "string" and self.value == tostring(value) then
			return true
		elseif type(self.value) == "number" and self.value == tonumber(value) then
			return true
		end
		return false
	end
}
