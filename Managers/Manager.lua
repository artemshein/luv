local Object = require"ProtOo"

module(...)

return Object:extend{
	__tag = "Managers.Manager",

	init = function (self, model)
		self.model = model
	end,
}
