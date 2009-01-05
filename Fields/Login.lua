local Char = require"Fields.Char"

module(...)

return Char:extend{
	__tag = "Fields.Login",
	
	init = function (self, params)
		params = params or {}
		params.minLength = 1
		params.maxLength = 32
		params.required = true
		params.unique = true
		params.regexp = "^[a-zA-Z0-9_%.%-]+$"
		Char.init(self, params)
	end
}
