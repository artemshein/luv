local require = require
local Reference, Exception = require"Fields.Reference", require"Exception"

module(...)

return Reference:extend{
	__tag = "Fields.ManyToOne",

	init = function (self, params)
		self:setParams(params)
	end,
	setValue = function (self, value)
		if value ~= nil and (not value:isKindOf(require(self.ref))) then
			Exception:new("Instance of "..self.ref.." or nil required!"):throw()
		end
		Reference.setValue(self, value)
	end
}
