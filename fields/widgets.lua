local string = require "luv.string"
local table = require "luv.table"
local tostring, io, type = tostring, io, type
local os, tr = os, tr
local pairs, ipairs, require = pairs, ipairs, require
local Widget, html = require "luv".Widget, require "luv.utils.html"
local json = require "luv.utils.json"

module(...)

local Field = Widget:extend{
	__tag = .....".Field";
	_fieldId = function (self, f, form)
		return f:id() or (form:id()..string.capitalize(f:name()))
	end;
	_renderType = function (self)
		return " type="..string.format("%q", self:type())
	end;
	_renderOnClick = function (self, f)
		if f:onClick() then
			return " onclick="..string.format("%q", f:onClick())
		end
		return ""
	end;
	_renderOnChange = function (self, f)
		if f:onChange() then
			return " onchange="..string.format("%q", f:onChange())
		end
		return ""
	end;
	_renderClasses = function (self, f)
		if f:classes() and not table.isEmpty(f:classes()) then
			return " class="..string.format("%q", table.join(f:classes(), " "))
		end
		return ""
	end;
	_renderName = function (self, f)
		return " name="..string.format("%q", html.escape(f:name()))
	end;
	_renderId = function (self, f, form)
		return " id="..string.format("%q", html.escape(self:_fieldId(f, form)))
	end;
	_renderValue = function (self, f)
		return " value="..string.format("%q", html.escape(tostring(f:value() or f:defaultValue() or "")))
	end;
	_renderHint = function (self, f)
		return (f:hint() and (" "..f:hint()) or "")
	end;
}

local Input = Field:extend{
	__tag = .....".Input";
	type = Field.property;
	init = function () end;
	render = function (self, field, form, tail)
		tail = tail or ""
		return
		"<input"
		..self:_renderType()
		..self:_renderName(field)
		..self:_renderId(field, form)
		..self:_renderValue(field)
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..tail.." />"
		..self:_renderHint(field)
	end;
}

local TextArea = Field:extend{
	__tag = .....".TextArea";
	init = function () end;
	_renderValue = function (self, f)
		return html.escape(tostring(f:value() or f:defaultValue() or ""))
	end;
	render = function (self, field, form)
		return "<textarea"
		..self:_renderName(field)
		..self:_renderId(field, form)
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..">"
		..self:_renderValue(field)
		.."</textarea>"
		..self:_renderHint(field)
	end;
}

local Checkbox = Input:extend{
	__tag = .....".Checkbox";
	_type = "checkbox";
	render = function (self, field, form)
		local tail = ""
		if field:value() == 1 then
			tail = ' checked="checked"'
		end
		return "<input"
		..self:_renderType()
		..self:_renderName(field)
		..self:_renderId(field, form)
		..' value="1"'
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..tail.." />"
	end;
}

local FileInput = Input:extend{
	__tag = .....".FileInput";
	_type = "file";
	render = function (self, field, form, tail)
		tail = tail or ""
		return
		"<input"
		..self:_renderType()
		..self:_renderName(field)
		..self:_renderId(field, form)
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..tail.." />"
		..self:_renderHint(field)
	end
}

local TextInput = Input:extend{
	__tag = .....".TextInput";
	_type = "text";
	render = function (self, field, form, tail)
		return Input.render(self, field, form, (tail or "").." maxlength="..string.format("%q", field:maxLength()))
	end
}

local PhoneInput = TextInput:extend{
	__tag = .....".PhoneInput";
	render = function (self, ...)
		return "+"..TextInput.render(self, ...)
	end;
}

local HiddenInput = TextInput:extend{
	__tag = .....".HiddenInput";
	_type = "hidden";
}

local PasswordInput = TextInput:extend{
	__tag = .....".PasswordInput";
	_type = "password";
}

local Button = Input:extend{
	__tag = .....".Button";
	_type = "button";
	render = function (self, field, form, tail)
		tail = tail or ""
		return Input.render(self, field, form, tail)
	end;
}

local SubmitButton = Button:extend{
	__tag = .....".SubmitButton";
	_type = "submit";
}

local ImageButton = Button:extend{
	__tag = .....".ImageButton";
	_type = "image";
	render = function (self, field, form)
		local tail = " src="..string.format("%q", field:src())
		return Button.render(self, field, form, tail)
	end
}

local Select = Field:extend{
	__tag = .....".Select";
	init = function () end;
	render = function (self, field, form)
		local models = require "luv.db.models"
		local fields = require "luv.fields"
		local classes = field:classes()
		local values, fieldValue = "", field:value()
		if not field:required() then values = "<option></option>" end
		local choices = field:choices()
		if "function" == type(choices) then
			choices = choices()
		end
		if choices.isA and choices:isA(models.QuerySet) then
			choices = choices:value()
		end
		for _, v in ipairs(choices) do
			local key, value
			if v.isA and v:isA(models.Model) then
				key = v.pk
				value = v
			else
				key = tostring(v[1])
				value = v[2]
			end
			local selected
			if "table" ~= type(fieldValue) then
				selected = tostring(fieldValue) == tostring(key)
			else
				selected = fieldValue == value
			end
			values = values.."<option value="..string.format("%q", key)..(selected and ' selected="selected"' or "")..">"..html.escape(tostring(value)).."</option>"
		end
		return "<select"
		..self:_renderId(field, form)
		..self:_renderName(field)
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..">"..values.."</select>"
		..self:_renderHint(field)
	end;
}

local MultipleSelect = Select:extend{
	__tag = .....".MiltipleSelect";
	render = function (self, field, form)
		local fields = require "luv.fields"
		local classes = field:classes()
		local values, fieldValue = "", field:value()
		local choices = field:choices()
		if "function" == type(choices) then
			choices = choices()
		end
		for k, v in pairs(choices) do
			local founded = false
			for _, val in ipairs(fieldValue) do
				if tostring(val) == tostring(v.isA and v.pk or v) then
					founded = true
					break
				end
			end
			values = values.."<option value="..string.format("%q", tostring(v.pk))..(founded and ' selected="selected"' or "")..">"..tostring(v).."</option>"
		end
		return '<select multiple="multiple"'
		..self:_renderId(field, form)
		..self:_renderName(field)
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..">"..values.."</select>"
		..self:_renderHint(field)
	end;
}

local NestedSetSelect = Select:extend{
	__tag = .....".NestedSetSelect";
	render = function (self, field, form)
		local data, minLevel = {}
		local choices = field:choices()
		if "function" == type(choices) then
			choices = choices()
		end
		for _, v in ipairs(choices) do
			local level = v.level
			minLevel = (minLevel and (minLevel < level and minLevel or level)) or level
			data[v.pk] = {value=v.pk;label=tostring(v);hasChildren=v:hasChildren();left=v.left;right=v.right;level=v.level}
		end
		local id = fieldId(form, field)
		local value = field:value()
		return
		"<div id="..string.format("%q", id.."Back").."></div>"
		..Select.render(self, field, form)
		..'<script type="text/javascript" language="JavaScript">//<![CDATA[\n'
		.."var nestedSetData = nestedSetData || {};\nnestedSetData['"..id.."'] = {minLevel: "..minLevel..", data: "
		..json.serialize(data)
		.."};\nluv.nestedSetSelect("..string.format("%q", id)..(value and "" ~= value and (", luv.nestedSetGetParentFor("..string.format("%q", id)..", "..string.format("%q", value)..")") or "")..");"
		..(value and "" ~= value and ("luv.setFieldValue("..string.format("%q", id)..", "..string.format("%q", value)..");") or "").."\n//]]></script>"
	end;
}

local DateInput = TextInput:extend{
	__tag = .....".DateInput";
	_format = "%d.%m.%Y";
	format = TextInput.property;
	_regional = "ru";
	regional = TextInput.property;
	_renderValue = function (self, f)
		local value = f:value() or f:defaultValue()
		if value then
			value = os.date(self:format(), value)
		end
		return " value="..string.format("%q", html.escape(value or ""))
	end;
	render = function (self, field, form, tail)
		local html =
		"<input"
		..self:_renderType()
		..self:_renderName(field)
		..self:_renderId(field, form)
		..self:_renderValue(field)
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..(tail or "").." />"
		..self:_renderHint(field)
		local js = (js or "").."$('#"..self:_fieldId(field, form).."').datepicker($.datepicker.regional['"..self:regional().."']);"
		return html, js
	end;
}

local Time = TextInput:extend{
	__tag = .....".Time";
}

local Datetime = TextInput:extend{
	__tag = .....".Datetime";
	_format = "%Y-%m-%d %H:%M:%S";
	format = TextInput.property;
	init = function () end;
	_renderValue = function (self, f)
		local value = field:value() or field:defaultValue()
		if value then
			value = os.date(self:format(), value)
		end
		return " value="..string.format("%q", html.escape(value or ""))
	end;
	render = function (self, field, form, tail)
		tail = tail or ""
		return
		"<input"
		..self:_renderType()
		..self:_renderName(field)
		..self:_renderId(field, form)
		..self:_renderValue(field)
		..self:_renderClasses(field)
		..self:_renderOnClick(field)
		..self:_renderOnChange(field)
		..tail.." />"
		..self:_renderHint(field)
	end
}

return {
	TextArea=TextArea;TextInput=TextInput;PhoneInput=PhoneInput;
	HiddenInput=HiddenInput;PasswordInput=PasswordInput;
	FileInput=FileInput;DateInput=DateInput;Button=Button;
	SubmitButton=SubmitButton;ImageButton=ImageButton;Checkbox=Checkbox;
	Select=Select;MultipleSelect=MultipleSelect;
	NestedSetSelect=NestedSetSelect;Datetime=Datetime;Time=Time;
}
