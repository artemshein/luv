local error, tr, select = error, tr, select
local require, tostring = require, tostring
local pairs, tonumber, ipairs, os, type, io = pairs, tonumber, ipairs, os, type, io
local table = require "luv.table"
local Object, validators, Widget, widgets, string = require"luv.oop".Object, require"luv.validators", require"luv".Widget, require"luv.fields.widgets", require "luv.string"
local fs = require 'luv.fs'
local exceptions = require "luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try
local f = require "luv.function".f
local capitalize = string.capitalize

module(...)

local MODULE = ...

local Field = Object:extend{
	__tag = .....".Field";
	validators = Object.property;
	errors = Object.property;
	container = Object.property;
	unique = Object.property;
	pk = Object.property;
	name = Object.property;
	value = Object.property;
	choices = Object.property;
	defaultValue = Object.property;
	classes = Object.property;
	widget = Object.property;
	onClick = Object.property;
	onChange = Object.property;
	onLoad = Object.property;
	hint = Object.property;
	ajaxWidget = Object.property;
	init = function (self, params)
		if self._parent._parent == Object then
			Exception "can't instantiate abstract class"
		end
		self:validators{}
		self:errors{}
		self:params(params)
	end,
	clone = function (self)
		local new = Object.clone(self)
		new:validators(table.map(self:validators(), f "a:clone()"))
		return new
	end,
	params = function (self, params)
		params = params or {}
		self:pk(params.pk or false)
		self:unique(params.unique or false)
		self:required(params.required or false)
		self:label(params.label)
		self:widget(params.widget)
		self:onClick(params.onClick)
		self:onChange(params.onChange)
		self:hint(params.hint)
		if params.choices then self:choices(params.choices) end
		self:required(params.required)
		self:defaultValue(params.defaultValue)
		return self
	end,
	required = function (self, ...)
		if select("#", ...) > 0 then
			self._required = (select(1, ...))
			if self._required then
				self:validator("filled", validators.Filled())
				self:addClass "required"
			end
			return self
		else
			return self._required
		end
	end;
	id = function (self, ...)
		if select("#", ...) > 0 then
			self._id = (select(1, ...))
			return self
		else
			if not self._id then
				self._id = self:container():id()..string.capitalize(self:name())
			end
			return self._id
		end
	end;
	label = function (self, ...)
		if select("#", ...) > 0 then
			self._label = (select(1, ...))
			return self
		else
			return self._label or capitalize(tr(self:name()))
		end
	end;
	addError = function (self, error) table.insert(self._errors, error) return self end,
	addErrors = function (self, errors)
		for _, v in ipairs(errors) do table.insert(self._errors, v) end
		return self
	end,
	addClass = function (self, class)
		self._classes = self._classes or {}
		if not table.ifind(self._classes, class) then
			table.insert(self._classes, class)
		end
		return self
	end;
	addClasses = function (self, classes)
		self._classes = self._classes or {}
		for _, class in ipairs(classes) do
			self:addClass(class)
		end
		return self
	end;
	validator = function (self, key, ...)
		if select("#", ...) > 0 then
			self._validators[key] = (select(1, ...))
			return self
		else
			return self._validators[key]
		end
	end;
	isValid = function (self, value)
		local value = value or self:value()
		if nil == value then value = self:defaultValue() end
		self:errors{}
		if not self:validators() then
			return true
		end
		for _, val in pairs(self:validators()) do
			if not val:isValid(value) then
				self:addErrors(val:errors())
				return false
			end
		end
		return true
	end,
	-- Representation
	asHtml = function (self, form)
		if not self:widget() then
			Exception "widget required"
		end
		return self:widget():render(self, form or self:container())
	end;
	-- Ajax
	ajaxUrl = function (self, ...)
		if select("#", ...) > 0 then
			self:container():ajaxUrl((select(1, ...)))
			return self
		else
			return self:container():ajaxUrl()
		end
	end;
	asAjax = function (self, url)
		local html, js = (self:ajaxWidget() or self:widget()):render(self, self:container())
		return html..'<script type="text/javascript" language="JavaScript">//<![CDATA[\n'..(js or "").."$('#"..self:id().."').ajaxField('"..self:ajaxUrl().."', '"..self:container().pk.."', '"..self:name().."');\n//]]></script>"
	end;
}

local MultipleValues = Field:extend{
	__tag = .....'.MultipleValues';
	init = function (self, params)
		if not params then
			Exception 'choices required'
		end
		if not params.choices then
			params = {choices=params}
		end
		params.widget = params.widget or widgets.MultipleSelect()
		Field.init(self, params)
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			if 'table' ~= type(value) or value.isA then
				value = {value}
			end
			local resValue = {}
			for _, v in ipairs(value) do
				if 'table' == type(v) then
					table.insert(resValue, v:pk():value())
				else
					table.insert(resValue, v)
				end
			end
			value = resValue
			return Field.value(self, value)
		else
			return self._value or {}
		end
	end;
}

local Text = Field:extend{
	__tag = .....".Text",
	params = function (self, params)
		params = params or {}
		if false == params.maxLength then params.maxLength = 0 end
		if not params.widget then
			if params.choices then
				params.widget = widgets.Select()
			elseif "number" == type(params.maxLength) and (params.maxLength == 0 or params.maxLength > 65535) then
				params.widget = widgets.TextArea()
			else
				params.widget = widgets.TextInput()
			end
		end
		Field.params(self, params)
		if params.regexp then
			self:validator("regexp", validators.Regexp(params.regexp))
		end
		self:validator("length", validators.Length(params.minLength or 0, params.maxLength or 255))
	end,
	minLength = function (self)
		return self:validator "length":minLength()
	end,
	maxLength = function (self)
		return self:validator "length":maxLength()
	end
}

local Password = Text:extend{
	__tag = .....".Password";
	init = function (self, params)
		params = params or {}
		params.minLength = 6
		params.widget = widgets.PasswordInput()
		Text.init(self, params)
	end;
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
		params.maxLength = 255
		params.widget = widgets.FileInput()
		Text.init(self, params)
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local val = (select(1, ...))
			if 'table' == type(val) then
				val = val.tmpFilePath
			end
			Text.value(self, val)
			return self
		else
			return Text.value(self)
		end
	end;
	moveTo = function (self, path)
		if not self._value then
			return false
		end
		local tmpFile = fs.File(self.value)
		fs.File(path):openWriteAndClose(tmpFile:openReadAndClose "*a"):close()
		tmpFile:delete()
		self._value = path
		return true
	end;
}

local Image = File:extend{
	__tag = .....".Image";
	moveToWithExt = function (self, path)
		if not self._value then
			return false
		end
		local ext = require "luv.images".detectFormat(self._value)
		if not ext then
			return false
		end
		path = tostring(path)..'.'..ext
		local tmpFile = fs.File(self._value)
		fs.File(path):openWriteAndClose(tmpFile:openReadAndClose "*a")
		tmpFile:delete()
		self._value = path
		return true
	end;
}

local Phone = Text:extend{
	__tag = .....".Phone";
	init = function (self, params)
		params = params or {}
		params.minLength = 11
		params.maxLength = 11
		params.widget = params.widget or widgets.PhoneInput()
		params.regexp = "^[0-9]+$"
		Text.init(self, params)
	end;
}

local Int = Field:extend{
	__tag = .....".Int",
	init = function (self, params)
		params = params or {}
		if not params.widget then
			params.widget = params.choices and widgets.Select() or widgets.TextInput()
		end
		Field.init(self, params)
		self:validator("int", validators.Int())
	end,
	value = function (self, ...)
		if select("#", ...) > 0 then
			Field.value(self, (select(1, ...)))
			return self
		else
			return Field.value(self)
		end
	end;
	minLength = function (self) return self:required() and 1 or 0 end;
	maxLength = function (self) return 12 end;
}

local Boolean = Int:extend{
	__tag = .....".Boolean";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.Checkbox()
		Int.init(self, params)
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "string" == type(value) then
				value = tonumber(value)
			end
			if value then
				value = value ~= 0 and 1 or 0
			end
			Int.value(self, value)
			return self
		else
			return Int.value(self)
		end
	end;
	defaultValue = function (self)
		local defaultValue = Int.defaultValue(self)
		if nil == defaultValue then
			return nil
		end
		return defaultValue and 1 or 0
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

local Ip = Text:extend{
	__tag = function (self, params)
		params = params or {}
		params.minLength = 7
		params.maxLength = 39
		Text.init(self, params)
	end;
}

local Id = Int:extend{
	__tag = .....".Id",
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.HiddenInput()
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
		params.widget = params.widget or widgets.Button()
		Text.init(self, params)
	end;
}

local Submit = Button:extend{
	__tag = .....".Submit",
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {defaultValue=params}
		end
		params.widget = params.widget or widgets.SubmitButton()
		Button.init(self, params)
	end
}

local ImageButton = Button:extend{
	__tag = .....".Image";
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {src=params}
		end
		self:setSrc(params.src)
		params.widget = params.widget or widgets.ImageButton()
		Button.init(self, params)
	end;
	getSrc = function (self) return self.src end;
	setSrc = function (self, src) self.src = src return self end;
}

local Date = Field:extend{
	__tag = .....".Date";
	defaultFormat = "%d.%m.%Y";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.DateInput()
		if params.regional then
			params.widget:setRegional(params.regional)
		end
		self:setAutoNow(params.autoNow)
		Field.init(self, params)
		self:addClass "date"
	end;
	getAutoNow = function (self) return self.autoNow end;
	setAutoNow = function (self, autoNow) self.autoNow = autoNow return self end;
	getDefaultValue = function (self)
		if self.defaultValue then
			return self.defaultValue
		end
		if self:getAutoNow() then
			return os.time()
		end
		return nil
	end;
	setValue =  function (self, value)
		if "string" == type(value) then
			if string.match(value, "^%d%d%d%d[^%d]%d%d[^%d]%d%d") then
				self.value = os.time{
					year=tonumber(string.slice(value, 1, 4));
					month=tonumber(string.slice(value, 6, 7));
					day=tonumber(string.slice(value, 9, 10));
					hour=0;
					min=0;
					sec=0;
				}
			elseif string.match(value, "^%d%d[^%d]%d%d[^%d]%d%d%d%d") then
				self.value = os.time{
					year=tonumber(string.slice(value, 7, 10));
					month=tonumber(string.slice(value, 4, 5));
					day=tonumber(string.slice(value, 1, 2));
					hour=0;
					min=0;
					sec=0;
				}
			else
				self.value = nil
			end
		else
			self.value = value
		end
	end;
	__tostring = function (self)
		if self:getValue() then
			return os.date(self.defaultFormat, self:getValue())
		end
		return ''
	end;
	getMinLength = function (self) return 19 end;
	getMaxLength = function (self) return 19 end;
}

local Datetime = Field:extend{
	__tag = .....".Datetime";
	defaultFormat = "%Y-%m-%d %H:%M:%S";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.Datetime()
		self:setAutoNow(params.autoNow)
		Field.init(self, params)
		self:addClass "datetime"
	end;
	getAutoNow = function (self) return self.autoNow end;
	setAutoNow = function (self, autoNow) self.autoNow = autoNow return self end;
	getDefaultValue = function (self)
		if self.defaultValue then
			return self.defaultValue
		end
		if self:getAutoNow() then
			return os.time()--os.date("%Y-%m-%d %H:%M:%S")
		end
		return nil
	end;
	setValue =  function (self, value)
		if "string" == type(value) then
			try(function()
				self.value = os.time{
					year=tonumber(string.slice(value, 1, 4));
					month=tonumber(string.slice(value, 6, 7));
					day=tonumber(string.slice(value, 9, 10));
					hour=tonumber(string.slice(value, 12, 13));
					min=tonumber(string.slice(value, 15, 16));
					sec=tonumber(string.slice(value, 18, 19));
				}
			end):catch(function() -- Invalid date format
				self.value = nil
			end)
		else
			self.value = value
		end
	end;
	__tostring = function (self)
		if self:getValue() then
			return os.date(self.defaultFormat, self:getValue())
		end
		return ''
	end;
	getMinLength = function (self) return 19 end;
	getMaxLength = function (self) return 19 end;
}

local Time = Field:extend{
	__tag = .....".Time";
	defaultFormat = "%H:%M:%S";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.Time()
		self:setAutoNow(params.autoNow)
		Field.init(self, params)
		self:addClass "time"
	end;
	getAutoNow = function (self) return self.autoNow end;
	setAutoNow = function (self, autoNow) self.autoNow = autoNow return self end;
	getDefaultValue = function (self)
		if self.defaultValue then
			return self.defaultValue
		end
		if self:getAutoNow() then
			return os.date("%H:%M:%S")
		end
		return nil
	end;
	setValue = function (self, value)
		if "string" == type(value) then
			if string.match(value, "^%d%d[^%d]%d%d[^%d]%d%d$") then
				self.value = value
			elseif string.match(value, "^%d%d[^%d]%d%d$") then
				self.value = string.slice(value, 1, 2)..":"..string.slice(value, 4, 5)..":00"
			elseif string.match(value, "^%d%d$") then
				self.value = value..":00:00"
			else
				self.value = nil
			end
		else
			self.value = value
		end
	end;
	__tostring = function (self)
		return self:getValue() or ""
	end;
	getMinLength = function (self) return 1 end;
	getMaxLength = function (self) return 8 end;
}

local ModelSelect = Field:extend{
	__tag = .....".ModelSelect";
	init = function (self, params)
		if not params then
			Exception"Values required!"
		end
		if not params.choices then
			params = {choices=params}
		end
		params.widget = params.widget or widgets.Select
		Field.init(self, params)
	end;
	setValue = function (self, value)
		if "table" == type(value) then
			value = value:getPk():getValue()
		end
		return Field.setValue(self, value)
	end;
}

local ModelMultipleSelect = MultipleValues:extend{
	__tag = .....".ModelMultipleSelect";
	init = function (self, params)
		if not params then
			Exception "choices required"
		end
		if not params.choices then
			params = {choices=params}
		end
		params.widget = params.widget or widgets.MultipleSelect
		MultipleValues.init(self, params)
	end;
}

local NestedSetSelect = Field:extend{
	__tag = .....".NestedSetSelect";
	init = function (self, params)
		if not params then
			Exception"Values required!"
		end
		if not params.choices then
			params = {choices=params}
		end
		params.widget = params.widget or widgets.NestedSetSelect
		params.onChange = "luv.nestedSetSelect(this.id, luv.getFieldRawValue(this.id));"
		Field.init(self, params)
	end;
	setValue = function (self, value)
		if "table" == type(value) then
			value = value:getPk():getValue()
		end
		return Field.setValue(self, value)
	end;
}

return {
	Field=Field;MultipleValues=MultipleValues;Text=Text;
	Password=Password;Int=Int;Boolean=Boolean;Ip=Ip;Login=Login;Id=Id;
	Button=Button;ImageButton=ImageButton;Submit=Submit;Date=Date;
	Datetime=Datetime;Time=Time;Email=Email;Phone=Phone;Url=Url;
	File=File;Image=Image;ModelSelect=ModelSelect;
	ModelMultipleSelect=ModelMultipleSelect;
	NestedSetSelect=NestedSetSelect;
}
