local tr = tr
local string = require"luv.string"
local type, tonumber, tostring, table, ipairs = type, tonumber, tostring, table, ipairs
local json = require "luv.utils.json"
local Object = require"luv.oop".Object

module(...)

local Validator = Object:extend{
	__tag = .....".Validator";
	init = function (self)
		self:setErrors{}
	end;
	isValid = function (self)
		self:setErrors{}
	end;
	getErrorMsg = Object.abstractMethod;
	addError = function (self, error) table.insert(self._errors, error) return self end;
	addErrors = function (self, errors)
		for _, v in ipairs(errors) do
			table.insert(self._errors, v)
		end
		return self
	end;
	setErrors = function (self, errors) self._errors = errors return self end;
	getErrors = function (self) return self._errors end;
}

local Filled = Validator:extend{
	__tag = .....".Filled";
	getErrorMsg = function (self) return tr 'Field "%s" must be filled.' end;
	isValid = function (self, value)
		Validator.isValid(self, value)
		if type(value) == "string" and 0 ~= #value then
			return true
		elseif type(value) == "table" and (value.isKindOf or not table.isEmpty(value)) then
			return true
		elseif type(value) == "number" then
			return true
		end
		self:addError(self:getErrorMsg())
		return false
	end;
	getJs = function (self) return "validFilled()" end;
}

local Int = Validator:extend{
	__tag = .....".Int";
	getErrorMsg = function (self) return tr 'Field "%s" must be valid number.' end;
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
		self:addError(self:getErrorMsg())
		return false
	end;
	getJs = function (self) return "validInt()" end;
}

local Length = Validator:extend{
	__tag = .....".Length";
	init = function (self, minLength, maxLength)
		Validator.init(self)
		self.minLength = minLength
		self.maxLength = maxLength
	end;
	getErrorMsg = function (self) return tr 'Field "%s" has incorrect length.' end;
	getMaxLength = function (self) return self.maxLength end;
	getMinLength = function (self) return self.minLength end;
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
		if (self.maxLength ~= 0 and string.utf8len(value) > self.maxLength)
		or (self.minLength and string.utf8len(value) < self.minLength) then
			self:addError(self:getErrorMsg())
			return false
		end
		return true
	end;
	getJs = function (self) return "validLength("..(self:getMinLength() or "null")..", "..(self:getMaxLength() or "null")..")" end;
}

local Regexp = Validator:extend{
	__tag = .....".Regexp";
	init = function (self, regexp)
		Validator.init(self)
		self.regexp = regexp
	end;
	getErrorMsg = function (self) return tr 'Field "%s" has not valid value.' end;
	isValid = function (self, value)
		Validator.isValid(self, value)
		if value == nil or value == "" then
			return true
		end
		if not string.find(tostring(value), self.regexp) then
			self:addError(self:getErrorMsg())
			return false
		end
		return true
	end;
	getJs = function (self) return "validRegexp("..string.format("%q", self.regexp)..")" end;
}

local Value = Validator:extend{
	__tag = .....".Value";
	init = function (self, value)
		Validator.init(self)
		self.value = value
	end;
	getErrorMsg = function (self) return tr 'Field "%s" has invalid value.' end;
	isValid = function (self, value)
		Validator.isValid(self, value)
		if self.value == value then
			return true
		elseif type(self.value) == "string" and self.value == tostring(value) then
			return true
		elseif type(self.value) == "number" and self.value == tonumber(value) then
			return true
		end
		self:addError(self:getErrorMsg())
		return false
	end;
	getJs = function (self) return "validValue("..json.serialize(self.value)..")" end;
}

return {
	Validator=Validator;Filled=Filled;Int=Int;Length=Length;
	Regexp=Regexp;Value=Value;
}
