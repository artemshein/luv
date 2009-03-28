require "luv.string"
require "luv.table"
local tostring, debug, io = tostring, debug, io
local string, table, pairs = string, table, pairs
local Widget, html = require"luv".Widget, require"luv.utils.html"

module(...)

function getId(form, field)
	return field:getId() or (form:getId()..string.capitalize(field:getName()))
end

local Input = Widget:extend{
	__tag = .....".Input",
	tail = "",
	render = function (self, field, form)
		return [[<input type="]]..self.type..[[" name="]]..html.escape(field:getName())..[[" id="]]..html.escape(getId(form, field))..[[" value="]]..html.escape(tostring(field:getValue() or field:getDefaultValue() or ""))..[["]]..self.tail..[[ />]]
	end
}

local TextArea = Widget:extend{
	__tag = .....".TextArea";
	render = function (self, field, form)
		return [[<textarea name="]]..html.escape(field:getName())..[[" id="]]..html.escape(getId(form, field))..[[">]]..html.escape(tostring(field:getValue() or field:getDefaultValue() or ""))..[[</textarea>]]
	end;
}

local Checkbox = Input:extend{
	__tag = .....".Checkbox";
	type = "checkbox";
	render = function (self, field, form)
		if field:getValue() then
			self.tail = [[ checked="checked"]]
		end
		return Input.render(self, field, form)
	end;
}

local TextInput = Input:extend{
	__tag = .....".TextInput",
	type = "text",
	render = function (self, field, form)
		self.tail = [[ maxlength="]]..field:getMaxLength()..[["]]
		return Input.render(self, field, form)
	end
}

local HiddenInput = TextInput:extend{
	__tag = .....".HiddenInput",
	type = "hidden"
}

local PasswordInput = TextInput:extend{
	__tag = .....".PasswordInput",
	type = "password"
}

local Button = Input:extend{
	__tag = .....".Button",
	type = "button"
}

local SubmitButton = Button:extend{
	__tag = .....".SubmitButton",
	type = "submit"
}

local ImageButton = Button:extend{
	__tag = .....".ImageButton";
	type = "image";
	render = function (self, field, form)
		self.tail = [[ src="]]..field:getSrc()..[["]]
		return Button.render(self, field, form)
	end
}

local Select = Widget:extend{
	__tag = .....".Select";
	render = function (self, field, form)
		local values, fieldValue = "", field:getValue()
		for k, v in pairs(field:getRefModel():all():getValues()) do
			values = values..[[<option value="]]..tostring(v:getPk():getValue())..[["]]..(fieldValue == v and [[ selected="selected"]] or "")..[[>]]..tostring(v)..[[</option>]]
		end
		return [[<select id="]]..html.escape(getId(form, field))..[[" name="]]..html.escape(field:getName())..[[">]]..values..[[</select>]];
	end;
}

local MultipleSelect = Select:extend{
	__tag = .....".MiltipleSelect";
	render = function (self, field, form)
		local values, fieldValues = "", field:getValue()
		for k, v in pairs(field:all():getValues()) do
			local founded = fieldValues and table.find(fieldValues, v) or false
			values = values..[[<option value="]]..tostring(v:getPk():getValue())..[["]]..(founded and [[ selected="selected"]] or "")..[[>]]..tostring(v)..[[</option>]]
		end
		return [[<select multiple="multiple" id="]]..html.escape(getId(form, field))..[[" name="]]..html.escape(field:getName())..[[">]]..values..[[</select>]];
	end;
}

return {
	TextArea=TextArea;
	TextInput = TextInput,
	HiddenInput = HiddenInput,
	PasswordInput = PasswordInput,
	Button = Button,
	SubmitButton = SubmitButton;
	ImageButton=ImageButton;
	Checkbox=Checkbox;
	Select=Select;
	MultipleSelect=MultipleSelect;
}
