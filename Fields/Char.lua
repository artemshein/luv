local Field = require"Fields.Field"

module(...)

local Char = Field:extend{
	init = function (self, params)
		self:setParams(params)
		if not params.maxLength then
			self.maxLength = 255
		else
			self.maxLength = params.maxLength
		end
	end,
	getMaxLength = function (self)
		return self.maxLength
	end
}

return Char