local Field, Length, Regexp = require"Fields.Field", require"Validators.Length", require"Validators.Regexp"

module(...)

local Char = Field:extend{
	__tag = "Fields.Char",
	
	init = function (self, params)
		params = params or {}
		self:setParams(params)
		self.validators = {length = Length:new(params.minLength or 0, params.maxLength or 255)}
		if params.regexp then
			self.validators.regexp = Regexp:new(params.regexp)
		end
	end,
	getMinLength = function (self)
		return self.validators.length:getMinLength()
	end,
	getMaxLength = function (self)
		return self.validators.length:getMaxLength()
	end
}

return Char
