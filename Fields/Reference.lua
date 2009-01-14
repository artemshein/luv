local select, require, type = select, require, type
local Field, Exception = require"Fields.Field", require"Exception"

module(...)

local CLASS = select(1, ...)

return Field:extend{
	__tag = "Fields.Reference",

	init = function (self, ...)
		if self.parent == require(CLASS) then
			Exception"Instantiate of abstract class is not allowed!":throw()
		end
		Field.init(self, ...)
	end,
	setParams = function (self, params)
		if type(params) == "table" then
			self.ref = params.references or Exception"References required!":throw()
			Field.setParams(self, params)
			self.relationField = params.relationField
		else
			self.ref = params or Exception"References required!":throw()
		end
	end,
	getRelationField = function (self) return self.relationField end,
	getContainer = function (self) return self.container end,
	setContainer = function (self, container) self.container = container return self end,
	getRef = function (self) return self.ref end,
	getRole = function (self) return self.role end,
	setRole = function (self, role) self.role = role return self end,
	getRefModel = function (self)
		if not self.refModel then
			if not self.ref then
				Exception"References required!":throw()
			end
			self.refModel = require(self.ref)
		end
		return self.refModel
	end
}
