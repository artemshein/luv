require "luv.string"
require "luv.table"
local tostring, debug, io, type = tostring, debug, io, type
local os = os
local string, table, pairs, ipairs = string, table, pairs, ipairs
local Widget, html = require"luv".Widget, require"luv.utils.html"
local json = require "luv.utils.json"

module(...)

function getId(form, field)
	return field:getId() or (form:getId()..string.capitalize(field:getName()))
end

local Input = Widget:extend{
	__tag = .....'.Input';
	init = function () end;
	render = function (self, field, form, tail)
		tail = tail or ''
		local classes = field:getClasses()
		return
		'<input type='..string.format('%q', self.type)
		..' name='..string.format('%q', html.escape(field:getName()))
		..' id='..string.format('%q', html.escape(getId(form, field)))
		..' value='..string.format('%q', html.escape(tostring(field:getValue() or field:getDefaultValue() or '')))
		..(classes and (' class='..string.format('%q', table.join(classes, ' '))) or '')
		..tail..' />'
		..(field:getHint() and (' '..field:getHint()) or '')
	end
}

local TextArea = Widget:extend{
	__tag = .....'.TextArea';
	init = function () end;
	render = function (self, field, form)
		local classes = field:getClasses()
		return [[<textarea name="]]..html.escape(field:getName())
		..[[" id="]]..html.escape(getId(form, field))
		..(classes and ([[" class="]]..table.join(classes, ' ')) or '')
		..[[">]]..html.escape(tostring(field:getValue() or field:getDefaultValue() or ''))..[[</textarea>]]
		..(field:getHint() and (' '..field:getHint()) or '')
	end;
}

local Checkbox = Input:extend{
	__tag = .....'.Checkbox';
	type = 'checkbox';
	render = function (self, field, form)
		local tail = ''
		if field:getValue() then
			tail = [[ checked="checked"]]
		end
		local classes = field:getClasses()
		return [[<input type="]]..self.type..[[" name="]]..html.escape(field:getName())
		..[[" id="]]..html.escape(getId(form, field))
		..[[" value="1]]
		..(classes and ([[" class="]]..table.join(classes, ' ')) or '')
		..[["]]..tail..[[ />]]
	end;
}

local TextInput = Input:extend{
	__tag = .....'.TextInput';
	type = 'text';
	render = function (self, field, form)
		local tail = [[ maxlength="]]..field:getMaxLength()..[["]]
		return Input.render(self, field, form, tail)
	end
}

local PhoneInput = TextInput:extend{
	__tag = .....'.PhoneInput';
	render = function (self, ...)
		return '+'..TextInput.render(self, ...)
	end;
}

local HiddenInput = TextInput:extend{
	__tag = .....'.HiddenInput';
	type = 'hidden';
}

local PasswordInput = TextInput:extend{
	__tag = .....'.PasswordInput';
	type = 'password';
}

local Button = Input:extend{
	__tag = .....'.Button';
	type = 'button';
	render = function (self, field, form, tail)
		tail = tail or ''
		if field:getOnClick() then
			tail = tail..[[ onClick=]]..string.format('%q', field:getOnClick())
		end
		return Input.render(self, field, form, tail)
	end;
}

local SubmitButton = Button:extend{
	__tag = .....'.SubmitButton';
	type = 'submit';
}

local ImageButton = Button:extend{
	__tag = .....'.ImageButton';
	type = 'image';
	render = function (self, field, form)
		local tail = [[ src="]]..field:getSrc()..[["]]
		return Button.render(self, field, form, tail)
	end
}

local Select = Widget:extend{
	__tag = .....'.Select';
	init = function () end;
	render = function (self, field, form)
		local classes = field:getClasses()
		local values, fieldValue = "", field:getValue()
		if not field:isRequired() then values = [[<option></option>]] end
		local choices = field:getChoices()
		if 'function' == type(choices) then
			choices = choices()
		end
		for k, v in pairs(choices) do
			local value = v.isKindOf and v:getPk():getValue() or v
			values = values..[[<option value="]]..tostring(k)..[["]]..(tostring(k) == tostring(fieldValue) and [[ selected="selected"]] or '')..[[>]]..html.escape(tostring(v))..[[</option>]]
		end
		return [[<select id=]]..string.format('%q', html.escape(getId(form, field)))
		..' name='..string.format('%q', html.escape(field:getName()))
		..(field:getOnChange() and (' onchange='..string.format('%q', field:getOnChange())) or '')
		..(classes and (' class='..string.format('%q', table.join(classes, ' '))) or '')
		..'>'..values..'</select>'
		..(field:getHint() and (' '..field:getHint()) or '')
	end;
}

local MultipleSelect = Select:extend{
	__tag = .....'.MiltipleSelect';
	render = function (self, field, form)
		local classes = field:getClasses()
		local values, fieldValue = '', field:getValue()
		local choices = field:getChoices()
		if 'function' == type(choices) then
			choices = choices()
		end
		for k, v in pairs(choices) do
			local founded = false
			for _, val in ipairs(fieldValue) do
				if tostring(val) == tostring(v.isKindOf and v:getPk():getValue() or v) then
					founded = true
					break
				end
			end
			values = values..'<option value='..string.format('%q', tostring(v:getPk():getValue()))..(founded and ' selected="selected"' or '')..'>'..tostring(v)..'</option>'
		end
		return [[<select multiple="multiple" id=]]..string.format('%q', html.escape(getId(form, field)))
		..' name='..string.format('%q', html.escape(field:getName()))
		..(field:getOnChange() and (' onchange='..string.format('%q', field:getOnChange())) or '')
		..(classes and (' class='..string.format('%q', table.join(classes, ' '))) or '')
		..'>'..values..'</select>'
		..(field:getHint() and (' '..field:getHint()) or '')
	end;
}

local NestedSetSelect = Select:extend{
	__tag = .....'.NestedSetSelect';
	render = function (self, field, form)
		local data, minLevel = {}
		local choices = field:getChoices()
		if 'function' == type(choices) then
			choices = choices()
		end
		for _, v in ipairs(choices) do
			local level = v.level
			minLevel = (minLevel and (minLevel < level and minLevel or level)) or level
			data[v.pk] = {value=v.pk;label=tostring(v);hasChildren=v:hasChildren();left=v.left;right=v.right;level=v.level}
		end
		local id = getId(form, field)
		local value = field:getValue()
		return
		'<div id='..string.format('%q', id..'Back')..'></div>'
		..Select.render(self, field, form)
		..'<script type="text/javascript" language="JavaScript">//<![CDATA[\n'
		..'var nestedSetData = nestedSetData || {};\nnestedSetData["'..id..'"] = {"minLevel": '..minLevel..', "data": '
		..json.serialize(data)
		..'};\nluv.nestedSetSelect('..string.format('%q', id)..(value and '' ~= value and (', luv.nestedSetGetParentFor('..string.format('%q', id)..', '..string.format('%q', value)..')') or '')..');'
		..(value and '' ~= value and ('luv.setFieldValue('..string.format('%q', id)..', '..string.format('%q', value)..');') or '')..'\n//]]></script>'
	end;
}

local Datetime = TextInput:extend{
	__tag = .....'.Datetime';
	format = "%Y-%m-%d %H:%M:%S";
	init = function () end;
	render = function (self, field, form, tail)
		tail = tail or ''
		local classes = field:getClasses()
		return
		'<input type='..string.format('%q', self.type)
		..' name='..string.format('%q', html.escape(field:getName()))
		..' id='..string.format('%q', html.escape(getId(form, field)))
		..' value='..string.format('%q', html.escape(os.date(self.format, field:getValue() or field:getDefaultValue())))
		..(classes and (' class='..string.format('%q', table.join(classes, ' '))) or '')
		..tail..' />'
		..(field:getHint() and (' '..field:getHint()) or '')
	end
}

return {
	TextArea=TextArea;
	TextInput = TextInput;
	PhoneInput=PhoneInput;
	HiddenInput = HiddenInput,
	PasswordInput = PasswordInput,
	Button = Button,
	SubmitButton = SubmitButton;
	ImageButton=ImageButton;
	Checkbox=Checkbox;
	Select=Select;
	MultipleSelect=MultipleSelect;
	NestedSetSelect=NestedSetSelect;
	Datetime=Datetime;
}
