require "luv.debug"
local debug, error = debug, error
local pairs, tonumber, ipairs, table, os, type, io = pairs, tonumber, ipairs, table, os, type, io
local Object, validators, Widget, widgets, string = require"luv.oop".Object, require"luv.validators", require"luv".Widget, require"luv.fields.widgets", require "luv.string"
local Exception = require "luv.exceptions".Exception

module(...)

local MODULE = ...

local Field = Object:extend{
	__tag = .....".Field",
	init = function (self, params)
		if self.parent.parent == Object then
			Exception"Can not instantiate abstract class!":throw()
		end
		self.validators = {}
		self.errors = {}
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
		self.label = params.label
		self:setWidget(params.widget)
		if self.required then
			self.validators.filled = validators.Filled()
			self:addClass "required"
		end
		self:setDefaultValue(params.defaultValue)
		return self
	end,
	getContainer = function (self) return self.container end;
	setContainer = function (self, container) self.container = container return self end;
	isRequired = function (self) return self.required end,
	isUnique = function (self) return self.unique end,
	isPk = function (self) return self.pk end,
	getId = function (self) return self.id end,
	setId = function (self, id) self.id = id return self end,
	getLabel = function (self) return self.label or self:getName() end,
	setLabel = function (self, label) self.label = label return self end;
	getName = function (self) return self.name end;
	setName = function (self, name) self.name = name return self end;
	getValue = function (self) return self.value end,
	setValue = function (self, value) self.value = value return self end,
	getDefaultValue = function (self) return self.defaultValue end,
	setDefaultValue = function (self, val) self.defaultValue = val return self end,
	addError = function (self, error) table.insert(self.errors, error) return self end,
	addErrors = function (self, errors)
		local _, v for _, v in ipairs(errors) do table.insert(self.errors, v) end
		return self
	end,
	addClass = function (self, class)
		self.classes = self.classes or {}
		table.insert(self.classes, class)
		return self
	end;
	getClasses = function (self) return self.classes end;
	setClasses = function (self, classes) self.classes = classes return self end;
	setErrors = function (self, errors) self.errors = errors return self end,
	getErrors = function (self) return self.errors end,
	isValid = function (self, value)
		local value = value or self:getValue()
		if nil == value then value = self:getDefaultValue() end
		self:setErrors{}
		if not self.validators then
			return true
		end
		local _, val
		for _, val in pairs(self.validators) do
			if not val:isValid(value) then
				self:addErrors(val:getErrors())
				return false
			end
		end
		return true
	end,
	getWidget = function (self) return self.widget end,
	setWidget = function (self, widget) self.widget = widget return self end,
	asHtml = function (self, form) return self.widget:render(self, form or self:getContainer()) end;
}

local Text = Field:extend{
	__tag = .....".Text",
	setParams = function (self, params)
		params = params or {}
		if false == params.maxLength then params.maxLength = 0 end
		if not params.widget then
			if "number" == type(params.maxLength) and (params.maxLength == 0 or params.maxLength > 65535) then
				params.widget = widgets.TextArea
			else
				params.widget = widgets.TextInput
			end
		end
		Field.setParams(self, params)
		if params.regexp then
			self.validators.regexp = validators.Regexp(params.regexp)
		end
		self.validators.length = validators.Length(params.minLength or 0, params.maxLength or 255)
	end,
	getMinLength = function (self)
		return self.validators.length:getMinLength()
	end,
	getMaxLength = function (self)
		return self.validators.length:getMaxLength()
	end
}

local Email = Text:extend{
	__tag = .....".Email";
	init = function (self, params)
		params = params or {}
		params.maxLength = 255
		params.regexp = "^%a[%w%-%.]*@[%w%-%.]+%.%w+$"
		Text.init(self, params)
	end;
}

local Url = Text:extend{
	__tag = .....".Url";
	init = function (self, params)
		params = params or {}
		params.maxLength = 255;
		Text.init(self, params)
	end;
}

local File = Text:extend{
	__tag = .....".File";
	init = function (self, params)
		params = params or {}
		params.maxLength = 255;
		Text.init(self, params)
	end;
}

local Phone = Text:extend{
	__tag = .....".Phone";
	init = function (self, params)
		params = params or {}
		params.minLength = 12
		params.maxLength = 12
		Text.init(self, params)
	end;
}

local Int = Field:extend{
	__tag = .....".Int",
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.TextInput
		Field.init(self, params)
		self.validators.int = validators.Int()
	end,
	setValue = function (self, value)
		self.value = tonumber(value)
	end;
	getMinLength = function (self) return self:isRequired() and 1 or 0 end;
	getMaxLength = function (self) return 12 end;
}

local Boolean = Int:extend{
	__tag = .....".Boolean";
	init = function (self, params)
		params = params or {}
		params.required = true
		params.widget = params.widget or widgets.Checkbox
		Int.init(self, params)
	end;
	setValue = function (self, value)
		if "string" == type(value) then
			value = tonumber(value)
		end
		if nil == value then
			self.value = nil
		elseif "number" == type(value) then
			self.value = value
		else
			self.value = value and 1 or 0
		end
	end;
	getValue = function (self) if nil == self.value then return nil end return self.value ~= 0 end;
	getDefaultValue = function (self)
		if nil == self.defaultValue then return nil end
		if "boolean" == type(self.defaultValue) then return self.defaultValue and 1 or 0 end
		return self.defaultValue ~= 0
	end;
	isValid = function (self, value)
		value = value or self:getValue()
		if nil == value then value = self:getDefaultValue() end
		if nil == value then
			return Int.isValid(self, value)
		else
			return Int.isValid(self, value and 1 or 0)
		end
	end;
}

local Login = Text:extend{
	__tag = .....".Login",
	init = function (self, params)
		params = params or {}
		params.minLength = 1
		params.maxLength = 32
		params.required = true
		params.unique = true
		params.regexp = "^[a-zA-Z0-9_%.%-]+$"
		Text.init(self, params)
	end
}

local Id = Int:extend{
	__tag = .....".Id",
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.HiddenInput
		params.pk = true
		Int.init(self, params)
	end
}

local Button = Text:extend{
	__tag = .....".Button",
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {defaultValue=params}
		end
		params.defaultValue = params.defaultValue or 1
		params.widget = params.widget or widgets.Button
		Text.init(self, params)
	end;
	setParams = function (self, params)
		Text.setParams(self, params)
		if params.onClick then
			self:setOnClick(params.onClick)
		end
	end;
	getOnClick = function (self) return self.onClick end;
	setOnClick = function (self, onClick) self.onClick = onClick return self end;
}

local Submit = Button:extend{
	__tag = .....".Submit",
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {defaultValue=params}
		end
		params.widget = params.widget or widgets.SubmitButton
		Button.init(self, params)
	end
}

local Image = Button:extend{
	__tag = .....".Image";
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {src=params}
		end
		self:setSrc(params.src)
		params.widget = params.widget or widgets.ImageButton
		Button.init(self, params)
	end;
	getSrc = function (self) return self.src end;
	setSrc = function (self, src) self.src = src return self end;
}

local Datetime = Field:extend{
	__tag = .....".Datetime";
	setParams = function (self, params)
		params = params or {}
		self:setAutoNow(params.autoNow)
	end;
	getAutoNow = function (self) return self.autoNow end;
	setAutoNow = function (self, autoNow) self.autoNow = autoNow return self end;
	getDefaultValue = function (self)
		if self.defaultValue then
			return self.defaultValue
		end
		if self:getAutoNow() then
			return os.date("%Y-%m-%d %H:%M:%S")
		end
		return nil
	end;
	getValue = function (self)
		if not self.value then
			return self:getDefaultValue()
		end
		return self.value
	end;
	setValue =  function (self, value)
		if "string" == type(value) then
			self.value = os.time{
				year=tonumber(string.slice(value, 1, 4));
				month=tonumber(string.slice(value, 6, 7));
				day=tonumber(string.slice(value, 9, 10));
				hour=tonumber(string.slice(value, 12, 13));
				min=tonumber(string.slice(value, 15, 16));
				sec=tonumber(string.slice(value, 18, 19));
			}
		else
			self.value = value
		end
	end;
}

local ModelSelect = Field:extend{
	__tag = .....".ModelSelect";
	init = function (self, params)
		if not params then
			Exception"Values required!":throw()
		end
		if not params.values then
			params = {values=params}
		end
		self:setValues(params.values)
		params.widget = params.widget or widgets.Select
		Field.init(self, params)
	end;
	setValue = function (self, value)
		if "table" == type(value) then
			value = value:getPk():getValue()
		end
		return Field.setValue(self, value)
	end;
	getValues = function (self) return self.values end;
	setValues = function (self, values) self.values = values return self end;
}

local ModelMultipleSelect = Field:extend{
	__tag = .....".ModelMultipleSelect";
	init = function (self, params)
		if not params then
			Exception"Values required!":throw()
		end
		if not params.values then
			params = {values=params}
		end
		self:setValues(params.values)
		params.widget = params.widget or widgets.MultipleSelect
		Field.init(self, params)
	end;
	getValues = function (self) return self.values end;
	setValues = function (self, values) self.values = values return self end;
	setValue = function (self, value)
		if "table" ~= type(value) then
			value = {value}
		end
		if "table" == type(value) then
			local resValue = {}
			local k, v
			for k, v in pairs(value) do
				if "table" == type(v) then
					table.insert(resValue, v:getPk():getValue())
				else
					table.insert(resValue, v)
				end
			end
			value = resValue
		end
		return Field.setValue(self, value)
	end;
	getValue = function (self) return self.value or {} end;
}

return {
	Field = Field,
	Text = Text,
	Int = Int,
	Boolean=Boolean;
	Login = Login,
	Id = Id,
	Button = Button;
	Image = Image;
	Submit = Submit;
	Datetime=Datetime;
	Email=Email;
	Phone=Phone;
	Url=Url;File=File;
	ModelSelect=ModelSelect;ModelMultipleSelect=ModelMultipleSelect;
}
