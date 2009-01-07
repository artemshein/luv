local Field, Exception = require"Fields.Field", require"Exception"
local require, type = require, type

module(...)

return Field:extend{
	__tag = "Fields.Reference",

	setParams = function (self, params)
		Field.setParams(self, params)
		if type(params) == "table" then
			self.ref = params.references or Exception:new"References required!":throw()
		else
			self.ref = params or Exception:new"References required!":throw()
		end
	end,
	getRef = function (self) return self.ref end,
	getRole = function (self) return self.role end,
	setRole = function (self, role) self.role = role return self end,
	getRefModel = function (self)
		if not self.refModel then
			if not self.ref then
				Exception:new"References required!":throw()
			end
			self.refModel = require(self.ref)
		end
		return self.refModel
	end
}
