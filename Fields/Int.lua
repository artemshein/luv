local tonumber = tonumber
local Field, Int = require"Fields.Field", require"Validators.Int"

module(...)

return Field:extend{
	__tag = "Fields.Int",

	init = function (self, params)
		Field.init(self, params)
		self.validators.int = Int()
	end,
	setValue = function (self, value)
		self.value = tonumber(value)
	end
}
