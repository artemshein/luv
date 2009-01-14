local require, select, Object, Exception, Filled = require, select, require"ProtOo", require"Exception", require"Validators.Filled"
local Table, type, pairs = require"Table", type, pairs

module(...)

local CLASS = select(1, ...)

return Object:extend{
	__tag = "Fields.Field",

	init = function (self, params)
		if self.parent == require(CLASS) then
			Exception"Can not instantiate abstract class!":throw()
		end
		self.validators = {}
		self:setParams(params)
	end,
	clone = function (self)
		local new = Object.clone(self)
		-- Clone validators
		new.validators = {}
		if self.validators then
			local k, v
			for k, v in pairs(self.validators) do
				new.validators[k] = v:clone()
			end
		end
		return new
	end,
	setParams = function (self, params)
		params = params or {}
		self.pk = params.pk or false
		self.unique = params.unique or false
		self.required = params.required or false
		if self.required then
			self.validators.filled = Filled()
		end
		self.htmlWidget = params.htmlWidget
		self.defaultValue = params.defaultValue
		return self
	end,
	isRequired = function (self) return self.required end,
	isUnique = function (self) return self.unique end,
	isPk = function (self) return self.pk end,
	getValue = function (self) return self.value end,
	setValue = function (self, value) self.value = value return self end,
	getDefaultValue = function (self) return self.defaultValue end,
	setDefaultValue = function (self, val) self.defaultValue = val return self end,
	validate = function (self, value)
		local value = value or self.value
		if not self.validators then
			return true
		end
		local _, val
		for _, val in pairs(self.validators) do
			if not val:validate(value) then
				return false
			end
		end
		return true
	end,
	asHtml = function (self) return self.htmlWidget:render(self) end
}
