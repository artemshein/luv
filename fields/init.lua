local error, select = error, select
local require, tostring = require, tostring
local pairs, tonumber, ipairs, os, type, io = pairs, tonumber, ipairs, os, type, io
local table = require"luv.table"
local require = require
local Object, validators, Widget, widgets, string = require"luv.oop".Object, require"luv.validators", require"luv".Widget, require"luv.fields.widgets", require "luv.string"
local fs, Struct = require"luv.fs", require"luv".Struct
local exceptions = require"luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try
local f = require"luv.function".f

module(...)

local MODULE = (...)
local property = Object.property

local Field = Object:extend{
	__tag = .....".Field";
	required = property("boolean", nil, function (self, value)
		self._required = value
		if self._required then
			self:validator("filled", validators.Filled())
			self:addClass"required"
		end
		return self
	end);
	id = property("string", function (self)
		if not self._id then
			self:id(self:container():htmlId()..self:name():capitalize())
		end
		return self._id
	end);
	label = property("string", function (self)
		if not self._label then
			self:label(self:name())
		end
		return self._label
	end);
	validators = property "table";
	errors = property "table";
	container = property(Struct);
	unique = property "boolean";
	pk = property "boolean";
	name = property "string";
	value = property;
	choices = property;
	defaultValue = property;
	classes = property "table";
	widget = property(Widget);
	onClick = property;
	onChange = property;
	onLoad = property;
	hint = property;
	ajaxWidget = property(Widget);
	init = function (self, params)
		if self:parent():parent() == Object then
			Exception"can't instantiate abstract class"
		end
		self:validators{}
		self:errors{}
		self:params(params)
	end,
	clone = function (self)
		local new = Object.clone(self)
		new:validators(table.map(self:validators(), function (val) return val:clone() end))
		return new
	end,
	params = function (self, params)
		params = params or {}
		self:pk(params.pk or false)
		self:unique(params.unique or false)
		self:required(params.required or false)
		if params.label then self:label(params.label) end
		if params.widget then self:widget(params.widget) end
		self:onClick(params.onClick)
		self:onChange(params.onChange)
		self:hint(params.hint)
		if params.choices then self:choices(params.choices) end
		if params.classes then self:classes(params.classes) end
		self:required(params.required or false)
		self:defaultValue(params.defaultValue)
		return self
	end;
	addError = function (self, error) table.insert(self._errors, error) return self end;
	addErrors = function (self, errors)
		for _, v in ipairs(errors) do table.insert(self._errors, v) end
		return self
	end;
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
	valid = function (self, value)
		local value = value or self:value()
		if nil == value then value = self:defaultValue() end
		self:errors{}
		if not self:validators() then
			return true
		end
		for _, val in pairs(self:validators()) do
			if not val:valid(value) then
				self:addErrors(val:errors())
				return false
			end
		end
		return true
	end,
	-- Representation
	asHtml = function (self, form)
		if not self:widget() then
			Exception"widget required"
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
	__tag = .....".MultipleValues";
	init = function (self, params)
		if not params then
			Exception"choices required"
		end
		if not params.choices then
			params = {choices=params}
		end
		params.widget = params.widget or widgets.MultipleSelect()
		Field.init(self, params)
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "table" ~= type(value) or value.isA then
				value = {value}
			end
			local resValue = {}
			for _, v in ipairs(value) do
				if "table" == type(v) then
					table.insert(resValue, v.pk)
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
			if "table" == type(val) then
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
		fs.File(path):openWriteAndClose(tmpFile:openReadAndClose"*a"):close()
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
		local ext = require"luv.images".detectFormat(self._value)
		if not ext then
			return false
		end
		path = tostring(path).."."..ext
		local tmpFile = fs.File(self._value)
		fs.File(path):openWriteAndClose(tmpFile:openReadAndClose"*a")
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
			local value = (select(1, ...))
			Field.value(self, value and tonumber(value))
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
	defaultValue = function (self, ...)
		if select("#", ...) > 0 then
			return Int.defaultValue(self, ...)
		else
			local defaultValue = Int.defaultValue(self)
			if nil == defaultValue then
				return nil
			end
			return defaultValue and 1 or 0
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
	src = property "string";
	init = function (self, params)
		params = params or {}
		if "table" ~= type(params) then
			params = {src=params}
		end
		self:src(params.src)
		params.widget = params.widget or widgets.ImageButton()
		Button.init(self, params)
	end;
}

local Date = Field:extend{
	__tag = .....".Date";
	_defaultFormat = "%d.%m.%Y";
	autoNow = property "boolean";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.DateInput()
		if params.regional then
			params.widget:regional(params.regional)
		end
		self:autoNow(params.autoNow or false)
		Field.init(self, params)
		self:addClass "date"
	end;
	defaultValue = function (self, ...)
		if select("#", ...) > 0 then
			return Field.defaultValue(self, ...)
		else
			if self._defaultValue then
				return self._defaultValue
			end
			if self:autoNow() then
				return os.time()
			end
			return nil
		end
	end;
	value =  function (self, ...)
		if select("#", ...) > 0 then
			local value = select(1, ...)
			if "string" == type(value) then
				if value:match"^%d%d%d%d[^%d]%d%d[^%d]%d%d" then
					self._value = os.time{
						year=tonumber(value:slice(1, 4));
						month=tonumber(value:slice(6, 7));
						day=tonumber(value:slice(9, 10));
						hour=0;
						min=0;
						sec=0;
					}
				elseif value:match"^%d%d[^%d]%d%d[^%d]%d%d%d%d" then
					self._value = os.time{
						year=tonumber(value:slice(7, 10));
						month=tonumber(value:slice(4, 5));
						day=tonumber(value:slice(1, 2));
						hour=0;
						min=0;
						sec=0;
					}
				else
					self._value = nil
				end
			else
				self._value = value
			end
		else
			return Field.value(self)
		end
	end;
	__tostring = function (self)
		if self:value() then
			return os.date(self._defaultFormat, self:value())
		end
		return ""
	end;
	minLength = function (self) return 19 end;
	maxLength = function (self) return 19 end;
}

local Datetime = Field:extend{
	__tag = .....".Datetime";
	_defaultFormat = "%Y-%m-%d %H:%M:%S";
	autoNow = property "boolean";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.Datetime()
		self:autoNow(params.autoNow)
		Field.init(self, params)
		self:addClass "datetime"
	end;
	defaultValue = function (self, ...)
		if select("#", ...) > 0 then
			return Field.defaultValue(self, ...)
		else
			if self._defaultValue then
				return self._defaultValue
			end
			if self:autoNow() then
				return os.time()
			end
			return nil
		end
	end;
	value =  function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "string" == type(value) then
				try(function()
					self._value = os.time{
						year=tonumber(value:slice(1, 4));
						month=tonumber(value:slice(6, 7));
						day=tonumber(value:slice(9, 10));
						hour=tonumber(value:slice(12, 13));
						min=tonumber(value:slice(15, 16));
						sec=tonumber(value:slice(18, 19));
					}
				end):catch(function() -- Invalid date format
					self._value = nil
				end)
			else
				self._value = value
			end
		else
			return Field.value(self)
		end
	end;
	__tostring = function (self)
		if self:value() then
			return os.date(self._defaultFormat, self:value())
		end
		return ""
	end;
	getMinLength = function (self) return 19 end;
	getMaxLength = function (self) return 19 end;
}

local Time = Field:extend{
	__tag = .....".Time";
	_defaultFormat = "%H:%M:%S";
	autoNow = property "boolean";
	init = function (self, params)
		params = params or {}
		params.widget = params.widget or widgets.Time()
		self:autoNow(params.autoNow or false)
		Field.init(self, params)
		self:addClass "time"
	end;
	defaultValue = function (self, ...)
		if select("#", ...) > 0 then
			return Field.defaultValue(self, ...)
		else
			if self._defaultValue then
				return self._defaultValue
			end
			if self:autoNow() then
				return os.date("%H:%M:%S")
			end
			return nil
		end
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "string" == type(value) then
				if value:match"^%d%d[^%d]%d%d[^%d]%d%d$" then
					self._value = value
				elseif value:match"^%d%d[^%d]%d%d$" then
					self._value = value:slice(1, 2)..":"..value:slice(4, 5)..":00"
				elseif value:match"^%d%d$" then
					self._value = value..":00:00"
				else
					self._value = nil
				end
			else
				self._value = value
			end
		else
			return Field.value(self)
		end
	end;
	__tostring = function (self)
		return self:value() or ""
	end;
	minLength = function (self) return 1 end;
	maxLength = function (self) return 8 end;
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
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "table" == type(value) then
				value = value.pk
			end
			return Field.value(self, value)
		else
			return Field.value(self)
		end
	end;
}

local ModelMultipleSelect = MultipleValues:extend{
	__tag = .....".ModelMultipleSelect";
	init = function (self, params)
		if not params then
			Exception"choices required"
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
			Exception"values required"
		end
		if not params.choices then
			params = {choices=params}
		end
		params.widget = params.widget or widgets.NestedSetSelect
		params.onChange = "luv.nestedSetSelect(this.id, luv.getFieldRawValue(this.id));"
		Field.init(self, params)
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "table" == type(value) then
				value = value.pk
			end
			return Field.value(self, value)
		else
			Field.value(self)
		end
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
