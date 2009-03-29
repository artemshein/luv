require"luv.string"
require "luv.debug"
local type, tonumber, tostring, string, table, ipairs = type, tonumber, tostring, string, table, ipairs
local debug = debug
local Object = require"luv.oop".Object

module(...)

local Validator = Object:extend{
	__tag = .....".Validator",
	init = function (self)
		self.errors = {}
	end,
	isValid = function (self)
		self:setErrors{}
	end,
	addError = function (self, error) table.insert(self.errors, error) return self end,
	addErrors = function (self, errors)
		local _, v for _, v in ipairs(errors) do
			table.insert(self.errors, v)
		end
		return self
	end,
	setErrors = function (self, errors) self.errors = errors return self end,
	getErrors = function (self) return self.errors end
}

local Filled = Validator:extend{
	__tag = .....".Filled",
	init = function (self) Validator.init(self) return self end,
	isValid = function (self, value)
		Validator.isValid(self, value)
		if type(value) == "string" and 0 ~= #value then
			return true
		elseif type(value) == "table" and (value.isObject or not table.isEmpty(value)) then
			return true
		elseif type(value) == "number" then
			return true
		end
		self:addError "Field \"%s\" must be filled."
		return false
	end
}

local Int = Validator:extend{
	__tag = .....".Int",
	init = function (self) Validator.init(self) return self end,
	isValid = function (self, value)
		Validator.isValid(self, value)
		if value == nil then
			return true
		end
		if type(value) == "number" then
			return true
		elseif type(value) == "string" then
			if nil ~= tonumber(value) then
				return true
			end
		end
		self:addError "Field \"%s\" must be valid number."
		return false
	end
}

local Length = Validator:extend{
	__tag = .....".Length",
	init = function (self, minLength, maxLength)
		Validator.init(self)
		self.minLength = minLength
		self.maxLength = maxLength
	end,
	getMaxLength = function (self) return self.maxLength end,
	getMinLength = function (self) return self.minLength end,
	isValid = function (self, value)
		Validator.isValid(self, value)
		if value == nil or value == "" then
			return true
		end
		if type(value) == "number" then
			value = tostring(value)
		elseif type(value) ~= "string" then
			value = ""
		end
		if (self.maxLength ~= 0 and string.len(value) > self.maxLength)
		or (self.minLength and string.len(value) < self.minLength) then
			self:addError "Field \"%s\" has incorrect length."
			return false
		end
		return true
	end
}

local Regexp = Validator:extend{
	__tag = .....".Regexp",
	init = function (self, regexp)
		Validator.init(self)
		self.regexp = regexp
	end,
	isValid = function (self, value)
		Validator.isValid(self, value)
		if not string.find(tostring(value), self.regexp) then
			self:addError "Field \"%s\" has not valid value."
			return false
		end
		return true
	end
}

local Value = Validator:extend{
	__tag = .....".Value",
	init = function (self, value)
		Validator.init(self)
		self.value = value
	end,
	isValid = function (self, value)
		Validator.isValid(self, value)
		if self.value == value then
			return true
		elseif type(self.value) == "string" and self.value == tostring(value) then
			return true
		elseif type(self.value) == "number" and self.value == tonumber(value) then
			return true
		end
		self:addError "Field \"%s\" has invalid value."
		return false
	end
}

return {
	Validator = Validator,
	Filled = Filled,
	Int = Int,
	Length = Length,
	Regexp = Regexp,
	Value = Value
}
