local Struct, Table, Reference = require"Struct", require"Table", require"Fields.Reference"
local rawget, rawset, getmetatable, pairs = rawget, rawset, getmetatable, pairs

module(...)

local Model = Struct:extend{
	__tag = "Models.Model",
	
	setFields = function (self, fields)
		self.fields = fields
		for k, v in pairs(fields) do
			v:setName(k)
			if v:isKindOf(Reference) then
				v:setModel(self)
			end
		end
	end
}

return Model