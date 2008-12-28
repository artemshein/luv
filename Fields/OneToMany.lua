local Reference, Exception = require"Fields.Reference", require"Exception"

module(...)

local OneToMany = Reference:extend{
	__tag = "Fields.OneToMany",

	init = function (self, params)
		self.references = params.references or Exception:new"References required!":throw()
		self.refModel = require(self.references):new()
	end
}

return OneToMany