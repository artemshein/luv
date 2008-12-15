local Field, Length = require"Fields.Field", require"Validators.Length"

module(...)

local Char = Field:extend{
	__tag = "Fields.Char",
	
	init = function (self, params)
		params = params or {}
		self:setParams(params)
		if not params.maxLength then
			self.maxLength = 255
		else
			self.maxLength = params.maxLength
		end
		if not params.minLength then
			self.validators.length = Length:new(self.maxLength)
		else
			self.minLength = params.minLength
			self.validators.length = Length:new(self.minLength, self.maxLength)
		end
	end,
	getMaxLength = function (self)
		return self.maxLength
	end
}

return Char