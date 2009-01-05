local Reference, Exception = require"Fields.Reference", require"Exception"

module(...)

return Reference:extend{
	__tag = "Fields.OneToMany",

	init = function (self, params)
		self:setParams(params)
	end,
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end
}
