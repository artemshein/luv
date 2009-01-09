local Field, Length, Regexp = require"Fields.Field", require"Validators.Length", require"Validators.Regexp"

module(...)

return Field:extend{
	__tag = "Fields.Char",

	setParams = function (self, params)
		params = params or {}
		Field.setParams(self, params)
		if params.regexp then
			self.validators.regexp = Regexp:new(params.regexp)
		end
		self.validators.length = Length:new(params.minLength or 0, params.maxLength or 255)
	end,
	getMinLength = function (self)
		return self.validators.length:getMinLength()
	end,
	getMaxLength = function (self)
		return self.validators.length:getMaxLength()
	end
}
