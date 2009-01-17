local type, tonumber, tostring = type, tonumber, tostring
local Object, Namespace, String = from"Luv":import("Object", "Namespace", "String")

module(...)

local Validator = Object:extend{
	__tag = .....".Validator",

	validate = Object.abstractMethod
}

local Filled = Validator:extend{
	__tag = .....".Filled",

	init = function (self) return self end,
	validate = function (self, value)
		if type(value) == "string" then
			return 0 ~= #value
		elseif type(value) ~= "nil" then
			return true
		end
		return false
	end
}

local Int = Validator:extend{
	__tag = .....".Int",

	init = function (self) return self end,
	validate = function (self, value)
		if value == nil then
			return true
		end
		if type(value) == "number" then
			return true
		elseif type(value) == "string" then
			return nil ~= tonumber(value)
		end
		return false
	end
}

local Length = Validator:extend{
	__tag = .....".Length",

	init = function (self, minLength, maxLength)
		self.minLength = minLength
		self.maxLength = maxLength
	end,
	getMaxLength = function (self) return self.maxLength end,
	getMinLength = function (self) return self.minLength end,
	validate = function (self, value)
		if type(value) == "number" then
			value = tostring(value)
		elseif type(value) ~= "string" then
			value = ""
		end
		if (self.maxLength ~= 0 and #value > self.maxLength) or (self.minLength and #value < self.minLength) then
			return false
		end
		return true
	end
}

local Regexp = Validator:extend{
	__tag = .....".Regexp",

	init = function (self, regexp)
		self.regexp = regexp
	end,
	validate = function (self, value)
		if not String.find(tostring(value), self.regexp) then
			return false
		end
		return true
	end
}

local Value = Validator:extend{
	__tag = .....".Value",

	init = function (self, value)
		self.value = value
	end,
	validate = function (self, value)
		if self.value == value then
			return true
		elseif type(self.value) == "string" and self.value == tostring(value) then
			return true
		elseif type(self.value) == "number" and self.value == tonumber(value) then
			return true
		end
		return false
	end
}

return Namespace:extend{
	__tag = ...,

	ns = ...,
	Validator = Validator,
	Filled = Filled,
	Int = Int,
	Length = Length,
	Regexp = Regexp,
	Value = Value
}
