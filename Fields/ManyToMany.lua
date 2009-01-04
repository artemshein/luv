local Reference = require"Fields.Reference"

module(...)

return Reference:extend{
	__tag = "Fields.ManyToMany",

	init = function (self, params)
		self:setParams(params)
	end
}
