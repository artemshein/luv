local Field = require"Fields.Field"

module(...)

local Int = Field:extend{
	init = function (self, params)
		self.parent:initParams(params)
		
	end
}