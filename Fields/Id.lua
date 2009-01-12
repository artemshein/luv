local Int = require"Fields.Int"

module(...)

return Int:extend{
	__tag = "Fields.Id",

	setParams = function (self, params)
		params = params or {}
		params.pk = true
		Int.setParams(self, params)
		return self
	end
}
