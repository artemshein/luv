local tonumber = tonumber
local Field = require"Fields.Field"

module(...)

return Field:extend{
	__tag = "Fields.Int",

	init = function (self) end,
	setValue = function (self, value)
		self.value = tonumber(value)
	end
}
