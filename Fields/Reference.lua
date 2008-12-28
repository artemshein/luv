local Field = require"Fields.Field"

module(...)

local Reference = Field:extend{
	__tag = "Fields.Reference",

	getModel = function (self) return self.model end,
	setModel = function (self, ref) self.model = ref return self end
}

return Reference