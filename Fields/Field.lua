local Object, Exception = require"ProtOo", require"Exception"
local Table, type, pairs = require"Table", type, pairs

module(...)

local Field = Object:extend{
	__tag = "Fields.Field",
	
	pk = false,
	unique = false,
	required = false,
	validators = {},

	clone = function (self)
		local new = Object.clone(self)
		local k, v
		new.validators = {}
		for _, v in pairs(self.validators) do
			Table.insert(new.validators, v:clone())
		end
		return new
	end,
	setParams = function (self, params)
		params = params or {}
		self.name = params.name
		self.pk = params.pk or false
		self.unique = params.unique or false
		self.required = params.required or false
		self.htmlWidget = params.htmlWidget
		self.defaultValue = params.defaultValue
		return self
	end,
	isRequired = function (self) return self.required end,
	isUnique = function (self) return self.unique end,
	isPk = function (self) return self.pk end,
	getContainer = function (self) return self.container end,
	setContainer = function (self, container) self.container = container end,
	getName = function (self) return self.name end,
	setName = function (self, name) self.name = name return self end,
	getValue = function (self) return self.value end,
	setValue = function (self, value) self.value = value return self end,
	getDefaultValue = function (self) return self.defaultValue end,
	setDefaultValue = function (self, val) self.defaultValue = val return self end,
	validate = function (self)
		local _, val
		for _, val in pairs(self.validators) do
			if not val:validate(self.value) then
				return false
			end
		end
		return true
	end,
	asHtml = function (self) return self.htmlWidget:render(self) end
}

return Field
