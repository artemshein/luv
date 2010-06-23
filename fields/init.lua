local error, select, math, debug = error, select, math, debug
local require, tostring = require, tostring
local pairs, tonumber, ipairs, os, type, io = pairs, tonumber, ipairs, os, type, io
local table = require"luv.table"
local require = require
local Object, validators, Widget, widgets, string = require"luv.oop".Object, require"luv.validators", require"luv".Widget, require"luv.fields.widgets", require "luv.string"
local fs, Struct = require"luv.fs", require"luv".Struct
local exceptions = require"luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try
local json = require"luv.utils.json"

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
		else
			self:validator("filled", nil)
			self:removeClass"required"
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
	validators = property"table";
	errors = property"table";
	container = property(Struct);
	unique = property"boolean";
	pk = property"boolean";
	name = property"string";
	index = property"boolean";
	value = property;
	choices = property;
	default = property;
	classes = property"table";
	widget = property(Widget);
	onClick = property;
	onChange = property;
	onLoad = property;
	hint = property"string";
	ajaxWidget = property(Widget);
	_paramsDefaults = function (params, defaults)
		for key, val in pairs(defaults) do
			if nil == params[key] then
				params[key] = val
			end
		end
	end;
	_preprocessParams = function (params)
		params = params or {}
		if "table" ~= type(params) then
			params = {params}
		end
		for _, param in ipairs(params) do
			local t = type(param)
			if "boolean" == t then
				params.required = param
			elseif "string" == t then
				params.label = param
			end
		end
		return params
	end;
	init = function (self, params)
		if self:parent():parent() == Object then
			Exception"can't instantiate abstract class"
		end
		self:validators{}
		self:errors{}
		self:classes{}
		self:params(params)
	end,
	clone = function (self)
		local new = Object.clone(self)
		new:validators(table.map(self:validators(), "clone"))
		new:classes(table.copy(self:classes()))
		return new
	end,
	params = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {pk = false; unique = false; required = false; index = false})
		self:pk(params.pk)
		self:unique(params.unique)
		if params.label then self:label(params.label) end
		if params.widget then self:widget(params.widget) end
		self:onClick(params.onClick)
		self:onChange(params.onChange)
		if params.hint then self:hint(params.hint) end
		if params.choices then self:choices(params.choices) end
		if params.classes then self:classes(params.classes) end
		self:required(params.required)
		self:default(params.default)
		self:index(params.index)
		return self
	end;
	addError = function (self, error) table.insert(self._errors, error) return self end;
	addErrors = function (self, errors)
		for _, v in ipairs(errors) do table.insert(self._errors, v) end
		return self
	end;
	addClass = function (self, class)
		if not table.ifind(self._classes, class) then
			table.insert(self._classes, class)
		end
		return self
	end;
	removeClass = function (self, class)
		local pos = table.ifind(self._classes, class)
		if pos then
			table.remove(self._classes, pos)
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
		if nil == value then value = self:default() end
		self:errors{}
		if not self:validators() then
			return true
		end
		for _, val in pairs(self:validators()) do
			if not val:valid(value) then
				for _, error in ipairs(val:errors()) do
					self:addError(error % {field = self:label():tr():capitalize()})
				end
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
	asAjax = function (self, callback)
		local html, js = (self:ajaxWidget() or self:widget()):render(self, self:container())
		return html
			..'<script type="text/javascript" language="JavaScript">//<![CDATA[\n%(js)s$(%(id)s).ajaxField(%(ajaxUrl)s, %(pk)s, %(name)s, %(callback)s);\n//]]></script>'
			% {
				js=js or "";
				id=("%q"):format("#"..self:id());
				ajaxUrl=("%q"):format(self:ajaxUrl());
				pk=json.serialize(self:container().pk);
				name=("%q"):format(self:name());
				callback=callback or "null";
			}
	end;
	asInlineEditAjax = function (self, callback)
		local html, js = (self:ajaxWidget() or self:widget()):render(self, self:container())
		return html
			..'<span id=%(valueId)s></span><script type="text/javascript" language="JavaScript">//<![CDATA[\n%(js)s$(%(id)s).inlineEditAjaxField(%(ajaxUrl)s, %(pk)s, %(name)s, %(callback)s);\n//]]></script>'
			% {
				js=js or "";
				id=("%q"):format("#"..self:id());
				valueId=("%q"):format(self:id().."Value");
				ajaxUrl=("%q"):format(self:ajaxUrl());
				pk=json.serialize(self:container().pk);
				name=("%q"):format(self:name());
				callback=callback or "null";
			}
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
	__tag = .....".Text";
	_preprocessParams = function (params, defaults)
		params = params or {}
		if "table" ~= type(params) then
			params = {params}
		end
		for _, param in ipairs(params) do
			local t = type(param)
			if "boolean" == t then
				params.required = param
			elseif "string" == t then
				params.label = param
			elseif "number" == t then
				params.max = param
			end
		end
		return params
	end;
	params = function (self, params)
		params = self._preprocessParams(params)
		if false == params.max then params.max = 0 end
		if not params.widget then
			if params.choices then
				params.widget = widgets.Select()
			elseif "number" == type(params.max) and (params.max == 0 or params.max >= 65535) then
				params.widget = widgets.TextArea()
			else
				params.widget = widgets.TextInput()
			end
		end
		Field.params(self, params)
		if params.regexp then
			self:validator("regexp", validators.Regexp(params.regexp))
		end
		self:validator("length", validators.Length(params.min or 0, params.max or 255))
	end;
	min = function (self)
		return self:validator"length":min()
	end;
	max = function (self)
		return self:validator"length":max()
	end;
}

local Password = Text:extend{
	__tag = .....".Password";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {min = 6; widget = widgets.PasswordInput()})
		Text.init(self, params)
	end;
}

local Email = Text:extend{
	__tag = .....".Email";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {max = 255; regexp = "^%a[%w%-%.]*@[%w%-%.]+%.%w+$"})
		Text.init(self, params)
	end;
}

local Url = Text:extend{
	__tag = .....".Url";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {max = 255})
		Text.init(self, params)
	end;
}

local File = Text:extend{
	__tag = .....".File";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {max = 255; widget = widgets.FileInput()})
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
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {min = 11; max = 11; widgets = widgets.PhoneInput(); regexp = "^[0-9]+$"})
		Text.init(self, params)
	end;
}

local Int = Field:extend{
	__tag = .....".Int",
	init = function (self, params)
		params = self._preprocessParams(params)
		if not params.widget then
			params.widget = params.choices and widgets.Select() or widgets.TextInput()
		end
		Field.init(self, params)
		self:validator("int", validators.Int())
		if params.min or params.max then
			self:validator("intValueRange", validators.IntValueRange(params.min, params.max))
		end
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
	min = function (self)
		local intValueRange = self:validator"intValueRange"
		return intValueRange and intValueRange:min()
	end;
	max = function (self)
		local intValueRange = self:validator"intValueRange"
		return intValueRange and intValueRange:max()
	end;
}

local NonNegativeInt = Int:extend{
	__tag = .....".NonNegativeInt";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {min = 0})
		Int.init(self, params)
	end;
}

local Port = NonNegativeInt:extend{
	__tag = .....".Port";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {min = 0; max = 65535})
		NonNegativeInt.init(self, params)
	end;
}

local Float = Field:extend{
	__tag = .....".Float",
	init = function (self, params)
		params = self._preprocessParams(params)
		if not params.widget then
			params.widget = params.choices and widgets.Select() or widgets.TextInput()
		end
		Field.init(self, params)
		self:validator("float", validators.Float())
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
}

local Boolean = Int:extend{
	__tag = .....".Boolean";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.Checkbox()})
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
	default = function (self, ...)
		if select("#", ...) > 0 then
			return Int.default(self, ...)
		else
			local default = Int.default(self)
			if nil == default then
				return nil
			end
			return default and 1 or 0
		end
	end;
}

local Login = Text:extend{
	__tag = .....".Login",
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {min = 1; max = 32; required = true; unique = true; regexp = "^[a-zA-Z0-9_%.%-]+$"})
		Text.init(self, params)
	end
}

local Ip = Text:extend{
	__tag = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {min = 7; max = 39})
		Text.init(self, params)
	end;
}

local Id = Int:extend{
	__tag = .....".Id",
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.HiddenInput(); pk = true})
		Int.init(self, params)
	end
}

local Button = Text:extend{
	__tag = .....".Button",
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {default = 1; widget = widgets.Button()})
		Text.init(self, params)
	end;
}

local Submit = Button:extend{
	__tag = .....".Submit";
	_preprocessParams = function (params, defaults)
		params = params or {}
		if "table" ~= type(params) then
			params = {params}
		end
		for _, param in ipairs(params) do
			local t = type(param)
			if "boolean" == t then
				params.required = param
			elseif "string" == t then
				params.default = param
			elseif "number" == t then
				params.max = param
			end
		end
		return params
	end;
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.SubmitButton()})
		Button.init(self, params)
	end
}

local ImageButton = Button:extend{
	__tag = .....".Image";
	src = property"string";
	_preprocessParams = function (params, defaults)
		params = params or {}
		if "table" ~= type(params) then
			params = {params}
		end
		for _, param in ipairs(params) do
			local t = type(param)
			if "boolean" == t then
				params.required = param
			elseif "string" == t then
				params.src = param
			elseif "number" == t then
				params.max = param
			end
		end
		return params
	end;
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.ImageButton()})
		self:src(params.src or Exception"src required")
		Button.init(self, params)
	end;
}

local Date = Field:extend{
	__tag = .....".Date";
	_defaultFormat = "%d.%m.%Y";
	autoNow = property"boolean";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.DateInput(); autoNow = false})
		if params.regional then
			params.widget:regional(params.regional)
		end
		self:autoNow(params.autoNow)
		Field.init(self, params)
		self:addClass "date"
	end;
	default = function (self, ...)
		if select("#", ...) > 0 then
			return Field.default(self, ...)
		else
			if self._default then
				return self._default
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
						year = tonumber(value:slice(1, 4));
						month = tonumber(value:slice(6, 7));
						day = tonumber(value:slice(9, 10));
						hour = 0;
						min = 0;
						sec = 0;
					}
				elseif value:match"^%d%d[^%d]%d%d[^%d]%d%d%d%d" then
					self._value = os.time{
						year = tonumber(value:slice(7, 10));
						month = tonumber(value:slice(4, 5));
						day = tonumber(value:slice(1, 2));
						hour = 0;
						min = 0;
						sec = 0;
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
	min = function (self) return 19 end;
	max = function (self) return 19 end;
}

local Datetime = Field:extend{
	__tag = .....".Datetime";
	_defaultFormat = "%Y-%m-%d %H:%M:%S";
	autoNow = property"boolean";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.Datetime(); autoNow = false})
		self:autoNow(params.autoNow)
		Field.init(self, params)
		self:addClass"datetime"
	end;
	default = function (self, ...)
		if select("#", ...) > 0 then
			return Field.default(self, ...)
		else
			if self._default then
				return self._default
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
						year = tonumber(value:slice(1, 4));
						month = tonumber(value:slice(6, 7));
						day = tonumber(value:slice(9, 10));
						hour = tonumber(value:slice(12, 13));
						min = tonumber(value:slice(15, 16));
						sec = tonumber(value:slice(18, 19));
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
	min = function (self) return 19 end;
	max = function (self) return 19 end;
}

local Time = Field:extend{
	__tag = .....".Time";
	__tostring = function (self)
		local value = self:value()
		if not value then
			return ""
		end
		local time = os.date"*t"
		time.hour = math.floor(value/60/60)
		time.min = math.floor(value/60)%60
		time.sec = value%60
		return os.date(self:defaultFormat(), os.time(time))
	end;
	_defaultFormat = "%H:%M:%S";
	defaultFormat = property"string";
	autoNow = property"boolean";
	_strToSeconds = function (str)
		if str:match"^%d$" then str = "0"..str end
		if str:match"^%d%d$" then str = str..":00" end
		if str:match"^%d%d[^%d]%d%d$" then str = str..":00" end
		if str:match"^%d%d[^%d]%d%d[^%d]%d%d$" then
			return (tonumber(str:slice(1, 2))*60 + tonumber(str:slice(4, 5)))*60 + tonumber(str:slice(7, 8))
		end
	end;
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.Time(); autoNow = false})
		self:autoNow(params.autoNow)
		Field.init(self, params)
		self:addClass"time"
	end;
	default = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "string" == type(value) then
				value = self._strToSeconds(value)
			end
			return Field.default(self, value)
		else
			if self._default then
				return self._default
			end
			if self:autoNow() then
				return self._strToSeconds(os.date(self:defaultFormat()))
			end
			return nil
		end
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "string" == type(value) then
				value = self._strToSeconds(value)
			end
			return Field.value(self, value)
		else
			return Field.value(self)
		end
	end;
	min = function (self) return 1 end;
	max = function (self) return 8 end;
}

local ModelSelect = Field:extend{
	__tag = .....".ModelSelect";
	_preprocessParams = function (params)
		params = params or {}
		if "table" ~= type(params) then
			params = {params}
		end
		for _, param in ipairs(params) do
			local t = type(param)
			if "boolean" == t then
				params.required = param
			elseif "string" == t then
				params.label = param
			elseif "table" == t then
				params.choices = param
			end
		end
		return params
	end;
	init = function (self, params)
		self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.Select()})
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
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.MultipleSelect()})
		MultipleValues.init(self, params)
	end;
}

local NestedSetSelect = Field:extend{
	__tag = .....".NestedSetSelect";
	init = function (self, params)
		params = self._preprocessParams(params)
		self._paramsDefaults(params, {widget = widgets.NestedSetSelect(); onChange = "luv.nestedSetSelect(this.id, luv.getFieldRawValue(this.id));"})
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
	ModelMultipleSelect=ModelMultipleSelect;Float=Float;
	NestedSetSelect=NestedSetSelect;NonNegativeInt=NonNegativeInt;
}
