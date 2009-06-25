local error = error
local require, tostring = require, tostring
local pairs, tonumber, ipairs, table, os, type, io = pairs, tonumber, ipairs, table, os, type, io
local Object, validators, Widget, widgets, string = require"luv.oop".Object, require"luv.validators", require"luv".Widget, require"luv.fields.widgets", require "luv.string"
local fs = require 'luv.fs'
local exceptions = require "luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try

module(...)

local MODULE = ...

local Field = Object:extend{
	__tag = .....".Field",
	init = function (self, params)
		self.validators = {}
		self.errors = {}
		self:setParams(params)
	end,
	clone = function (self)
		local new = Object.clone(self)
		-- Clone validators
		new.validators = {}
		if self.validators then
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
		self:setOnClick(params.onClick)
		self:setOnChange(params.onChange)
		self:setHint(params.hint)
		if params.choices then self:setChoices(params.choices) end
		self:setRequired(params.required)
		self:setDefaultValue(params.defaultValue)
		return self
	end,
	getContainer = function (self) return self.container end;
	setContainer = function (self, container) self.container = container return self end;
	isRequired = function (self) return self._required end,
	setRequired = function (self, required)
		self._required = required
		if self._required then
			self.validators.filled = validators.Filled()
			self:addClass "required"
		end
		return self
	end;
	isUnique = function (self) return self.unique end,
	isPk = function (self) return self.pk end,
	getId = function (self)
		if not self.id then
			self.id = self.container:getId()..string.capitalize(self:getName())
		end
		return self.id
	end;
	setId = function (self, id) self.id = id return self end,
	getLabel = function (self) return self.label or self:getName() end,
	setLabel = function (self, label) self.label = label return self end;
	getName = function (self) return self.name end;
	setName = function (self, name) self.name = name return self end;
	getValue = function (self) return self.value end,
	setValue = function (self, value) self.value = value return self end,
	getChoices = function (self) return self.choices end;
	setChoices = function (self, choices) self.choices = choices return self end;
	getDefaultValue = function (self) return self.defaultValue end,
	setDefaultValue = function (self, val) self.defaultValue = val return self end,
	addError = function (self, error) table.insert(self.errors, error) return self end,
	addErrors = function (self, errors)
		for _, v in ipairs(errors) do table.insert(self.errors, v) end
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
	getClasses = function (self) return self._classes end;
	setClasses = function (self, classes) self._classes = classes return self end;
	setErrors = function (self, errors) self.errors = errors return self end,
	getErrors = function (self) return self.errors end,
	isValid = function (self, value)
		local value = value or self:getValue()
		if nil == value then value = self:getDefaultValue() end
		self:setErrors{}
		if not self.validators then
			return true
		end
		for _, val in pairs(self.validators) do
			if not val:isValid(value) then
				self:addErrors(val:getErrors())
				return false
			end
		end
		return true
	end,
	-- Representation
	getWidget = function (self) return self.widget end,
	setWidget = function (self, widget) self.widget = widget return self end,
	asHtml = function (self, form)
		if not self.widget then
			Exception "widget required"
		end
		return self.widget:render(self, form or self:getContainer())
	end;
	getOnClick = function (self) return self.onClick end;
	setOnClick = function (self, onClick) self.onClick = onClick return self end;
	getOnChange = function (self) return self.onChange end;
	setOnChange = function (self, onChange) self.onChange = onChange return self end;
	getOnLoad = function (self) return self._onLoad end;
	setOnLoad = function (self, onLoad) self._onLoad = onLoad return self end;
	getHint = function (self) return self.hint end;
	setHint = function (self, hint) self.hint = hint return self end;
	-- Ajax
	getAjaxUrl = function (self) return self.container:getAjaxUrl() end;
	setAjaxUrl = function (self, url) self.containt:setAjaxUrl(url) return self end;
	getAjaxWidget = function (self) return self._ajaxWidget end;
	setAjaxWidget = function (self, widget) self._ajaxWidget = widget return self end;
	asAjax = function (self, url)
		local html, js = (self:getAjaxWidget() or self:getWidget()):render(self, self:getContainer())
		return html..'<script type="text/javascript" language="JavaScript">//<![CDATA[\n'..(js or "").."$('#"..self:getId().."').ajaxField('"..self:getAjaxUrl().."', '"..self.container.pk.."', '"..self:getName().."');\n//]]></script>"
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
	getValue = function (self) return self.value or {} end;
	setValue = function (self, value)
		if 'table' ~= type(value) or value.isKindOf then
			value = {value}
		end
		local resValue = {}
		for _, v in ipairs(value) do
			if 'table' == type(v) then
				table.insert(resValue, v:getPk():getValue())
			else
				table.insert(resValue, v)
			end
		end
		value = resValue
		return Field.setValue(self, value)
	end;
}

local Text = Field:extend{
	__tag = .....".Text",
	setParams = function (self, params)
		params = params or {}
		if false == params.maxLength then params.maxLength = 0 end
		if not params.widget then
			if "number" == type(params.maxLength) and (params.maxLength == 0 or params.maxLength > 65535) then
				params.widget = widgets.TextArea()
			else
				params.widget = widgets.TextInput()
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
	setValue = function (self, val)
		if 'table' == type(val) then
			val = val.tmpFilePath
		end
		Text.setValue(self, val)
	end;
	moveTo = function (self, path)
		if not self.value then
			return false
		end
		local tmpFile = fs.File(self.value)
		fs.File(path):openWriteAndClose(tmpFile:openReadAndClose '*a'):close()
		tmpFile:delete()
		self.value = path
		return true
	end;
}

local Image = File:extend{
	__tag = .....'.Image';
	moveToWithExt = function (self, path)
		if not self.value then
			return false
		end
		local ext = require 'luv.images'.detectFormat(self.value)
		if not ext then
			return false
		end
		path = tostring(path)..'.'..ext
		local tmpFile = fs.File(self.value)
		fs.File(path):openWriteAndClose(tmpFile:openReadAndClose '*a')
		tmpFile:delete()
		self.value = path
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
		params.widget = params.widget or widgets.TextInput()
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
		params.widget = params.widget or widgets.Checkbox()
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
	__tag = .....'.ModelMultipleSelect';
	init = function (self, params)
		if not params then
			Exception 'choices required'
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
		params.onChange = 'luv.nestedSetSelect(this.id, luv.getFieldRawValue(this.id));'
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
	Field = Field;
	MultipleValues=MultipleValues;
	Text=Text;Password=Password;
	Int = Int,
	Boolean=Boolean;
	Ip=Ip;
	Login = Login,
	Id = Id,
	Button = Button;
	ImageButton = ImageButton;
	Submit = Submit;
	Date=Date;Datetime=Datetime;Time=Time;
	Email=Email;
	Phone=Phone;
	Url=Url;File=File;Image=Image;
	ModelSelect=ModelSelect;ModelMultipleSelect=ModelMultipleSelect;
	NestedSetSelect=NestedSetSelect;
}
