local string = require"luv.string"
local io = io
local type, tonumber, tostring, table, ipairs = type, tonumber, tostring, table, ipairs
local json = require"luv.utils.json"
local Object = require"luv.oop".Object

module(...)

local property = Object.property

local Validator = Object:extend{
	__tag = .....".Validator";
	errors = property"table";
	errorMsg = property"string";
	js = property;
	init = function (self) self:errors{} end;
	valid = function (self) self:errors{} return true end;
	addError = function (self, error) table.insert(self._errors, error) return self end;
	addErrors = function (self, errors)
		for _, v in ipairs(errors) do
			table.insert(self._errors, v)
		end
		return self
	end;
}

local Filled = Validator:extend{
	__tag = .....".Filled";
	_errorMsg = ('Field "%(field)s" must be filled.'):tr();
	_js = "validFilled()";
	valid = function (self, value)
		Validator.valid(self, value)
		if type(value) == "string" and 0 ~= #value then
			return true
		elseif type(value) == "table" and (value.isA or not table.empty(value)) then
			return true
		elseif type(value) == "number" then
			return true
		end
		self:addError(self:errorMsg())
		return false
	end;
}

local Int = Validator:extend{
	__tag = .....".Int";
	_errorMsg = ('Field "%(field)s" must be valid number.'):tr();
	_js = "validInt()";
	valid = function (self, value)
		Validator.valid(self, value)
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
		self:addError(self:errorMsg())
		return false
	end;
}

local NonNegative = Validator:extend{
	__tag = .....".NonNegative";
	_errorMsg = ('Field "%(field)s" must be bigger or equal to 0.'):tr();
	_js = "validNonNegative()";
	valid = function (self, value)
		Validator.valid(self, value)
		if value == nil then
			return true
		end
		if type(value) == "number" or type(value) == "string" then
			if tonumber(value) >= 0 then
				return true
			end
		end
		self:addError(self:errorMsg())
		return false
	end;
}

local IntValueRange = Validator:extend{
	__tag = .....".IntValueRange";
	_errorMsg = ('Field "%(field)s" must be at least %(min)s and at most %(max)s.'):tr();
	min = property"number";
	max = property"number";
	init = function (self, min, max)
		Validator.init(self)
		if min then self:min(min) end
		if max then self:max(max) end
	end;
	js =  function (self)
		return "validIntValueRange(%(min)s, %(max)s)" % {min = tonumber(self:min()) or "null"; max = tonumber(self:max()) or "null"}
	end;
	valid = function (self, value)
		Validator.valid(self, value)
		if value == nil then
			return true
		end
		if type(value) == "number" or type(value) == "string" then
			local intVal = tonumber(value)
			if (not self:min() or intVal >= self:min())
			and (not self:max() or intVal <= self:max()) then
				return true
			end
		end
		self:addError(self:errorMsg() % {min = self:min(); max = self:max()})
		return false
	end;
}

local Length = Validator:extend{
	__tag = .....".Length";
	_errorMsg = ('Field "%(field)s" has incorrect length.'):tr();
	min = property"number";
	max = property"number";
	init = function (self, min, max)
		Validator.init(self)
		self:min(min)
		self:max(max)
	end;
	valid = function (self, value)
		Validator.valid(self, value)
		if value == nil or value == "" then
			return true
		end
		if type(value) == "number" then
			value = tostring(value)
		elseif type(value) ~= "string" then
			value = ""
		end
		if (self:max() ~= 0 and string.utf8len(value) > self:max())
		or (self:min() and string.utf8len(value) < self:min()) then
			self:addError(self:errorMsg())
			return false
		end
		return true
	end;
	js = function (self) return "validLength("..(self:min() or "null")..", "..(self:max() or "null")..")" end;
}

local Regexp = Validator:extend{
	__tag = .....".Regexp";
	_errorMsg = ('Field "%(field)s" has not valid value.'):tr();
	regexp = property"string";
	init = function (self, regexp)
		Validator.init(self)
		self:regexp(regexp)
	end;
	valid = function (self, value)
		Validator.valid(self, value)
		if value == nil or value == "" then
			return true
		end
		if not tostring(value):find(self:regexp()) then
			self:addError(self:errorMsg())
			return false
		end
		return true
	end;
	js = function (self) return "validRegexp("..("%q"):format(self:regexp())..")" end;
}

local Value = Validator:extend{
	__tag = .....".Value";
	_errorMsg = ('Field "%(field)s" has invalid value.'):tr();
	value = property;
	init = function (self, value)
		Validator.init(self)
		self:value(value)
	end;
	valid = function (self, value)
		Validator.valid(self, value)
		local selfVal = self:value()
		if selfVal == value then
			return true
		elseif type(selfVal) == "string" and selfVal == tostring(value) then
			return true
		elseif type(selfVal) == "number" and selfVal == tonumber(value) then
			return true
		end
		self:addError(self:errorMsg())
		return false
	end;
	js = function (self) return "validValue("..json.serialize(self:value())..")" end;
}

local Float = Validator:extend{
	__tag = .....".Float";
	_errorMsg = ('Field "%(field)s" must be float.'):tr();
	_js = "validFloat()";
	valid = function (self, value)
		Validator.valid(self, value)
		if value == nil then
			return true
		end
		return true
	end;
}

return {
	Validator=Validator;Filled=Filled;Int=Int;Length=Length;
	Regexp=Regexp;Value=Value;NonNegative=NonNegative;Float=Float;
	IntValueRange=IntValueRange;
}
