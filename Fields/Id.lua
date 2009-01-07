local Int = require"Fields.Int"

module(...)

return Int:extend{
	__tag = "Fields.Id",

	init = function (self, params)
		Int.init(self, params)
		self.pk = true
	end
}
