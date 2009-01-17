local from, pairs, tonumber = from, pairs, tonumber
local Object, Namespace, Validators = from"Luv":import("Object", "Namespace", "Validators")

module(...)

local MODULE = ...

local Field = Object:extend{
	__tag = .....".Field",

	init = function (self, params)
		if self.parent.parent == Object then
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
			self.validators.filled = Validators.Filled()
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

local Char = Field:extend{
	__tag = .....".Char",

	setParams = function (self, params)
		params = params or {}
		Field.setParams(self, params)
		if params.regexp then
			self.validators.regexp = Validators.Regexp(params.regexp)
		end
		self.validators.length = Validators.Length(params.minLength or 0, params.maxLength or 255)
	end,
	getMinLength = function (self)
		return self.validators.length:getMinLength()
	end,
	getMaxLength = function (self)
		return self.validators.length:getMaxLength()
	end
}

local Int = Field:extend{
	__tag = .....".Int",

	init = function (self, params)
		Field.init(self, params)
		self.validators.int = Validators.Int()
	end,
	setValue = function (self, value)
		self.value = tonumber(value)
	end
}

local Login = Char:extend{
	__tag = .....".Login",

	init = function (self, params)
		params = params or {}
		params.minLength = 1
		params.maxLength = 32
		params.required = true
		params.unique = true
		params.regexp = "^[a-zA-Z0-9_%.%-]+$"
		Char.init(self, params)
	end
}

local Id = Int:extend{
	__tag = .....".Id",

	setParams = function (self, params)
		params = params or {}
		params.pk = true
		Int.setParams(self, params)
		return self
	end
}

return Namespace:extend{
	__tag = ...,

	ns = ...,
	Field = Field,
	Char = Char,
	Int = Int,
	Login = Login,
	Id = Id
}
