local select, require, type = select, require, type
local Fields, Exception = from"Luv":import("Fields", "Exception")

module(...)

return Fields.Field:extend{
	__tag = ...,

	init = function (self, ...)
		if self.parent.parent == Fields.Field then
			Exception"Instantiate of abstract class is not allowed!":throw()
		end
		Fields.Field.init(self, ...)
	end,
	setParams = function (self, params)
		if type(params) == "table" then
			self.relatedName = params.relatedName
			self.toField = params.toField
			if not params.references then Exception"References required!":throw() end
			if "table" == type(params.references) then
				self.refModel = params.references
			else
				self.ref = params.references
			end
			Fields.Field.setParams(self, params)
		else
			self.ref = params or Exception"References required!":throw()
		end
	end,
	getRelatedName = function (self) return self.relatedName end,
	setRelatedName = function (self, relatedName) self.relatedName = relatedName return self end,
	getToField = function (self) return self.toField end,
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
