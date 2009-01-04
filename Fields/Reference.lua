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
	getModel = function (self) return self.model end,
	setModel = function (self, ref) self.model = ref return self end,
	getRole = function (self) return self.role end,
	setRole = function (self, role) self.role = role return self end,
	getRefModel = function (self)
		if not self.refModel then
			local model = require(self.ref or Exception:new"References")
			self.refModel = model:new()
		end
		return self.refModel
	end
}
