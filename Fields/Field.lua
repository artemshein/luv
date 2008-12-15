local Object, Exception = require"ProtOo", require"Exception"
local type, pairs = type, pairs

module(...)

local Field = Object:extend{
	__tag = "Fields.Field",
	
	pk = false,
	unique = false,
	required = false,
	validators = {},
	
	setParams = function (self, params)
		params = params or {}
		if params.pk then
			self.pk = params.pk
		end
		if params.unique then
			self.unique = params.unique
		end
		if params.required then
			self.required = params.required
		end
		return self
	end,
	isRequired = function (self) return self.required end,
	isUnique = function (self) return self.unique end,
	isPk = function (self) return self.pk end,
	getValue = function (self) return self.value end,
	setValue = function (self, value)
		self.value = value
		return self
	end,
	validate = function (self)
		for i, val in pairs(self.validators) do
			if not val:validate(self.value) then
				return false
			end
		end
		return true
	end
}

return Field