local string = require"luv.string"
local tr, type, require, debug = tr, type, require, debug
local pairs, ipairs, io = pairs, ipairs, io
local Widget, widgets = require"luv".Widget, require"luv.fields.widgets"
local references = require"luv.fields.references"
local forms, fields, html = require"luv.forms", require"luv.fields", require"luv.utils.html"
local Exception = require"luv.exceptions".Exception
local json = require"luv.utils.json"

module(...)

local Form = Widget:extend{
	__tag = .....".FormWidget";
	_fieldId = function (self, f, form)
		return f:id() or (form:htmlId()..f:name():capitalize())
	end;
	_renderId = function (self, form)
		return form:htmlId() and (" id="..("%q"):format(form:htmlId())) or ""
	end;
	_renderAction = function (self, form)
		return " action="..("%q"):format(form:htmlAction() or "")
	end;
	renderFormHeader = function (self, form)
		local fileUploadFlag
		for _, f in ipairs(form:fields()) do
			if f:widget():isA(widgets.FileInput) then
				fileUploadFlag = true
			end
		end
		return
			"<form"
			..self:_renderId(form)
			..self:_renderAction(form)
			..' method="POST"'
			..(fileUploadFlag and ' enctype="multipart/form-data"' or "")
			..">"
	end;
	renderLabel = function (self, form, field)
		if not field:label() then
			return ""
		end
		local id = self:_fieldId(field, form)
		if not id then
			return field:label()..":"
		end
		return "<label for="..("%q"):format(html.escape(id))..">"..field:label():tr():capitalize().."</label>:"
	end;
	renderLabelCheckbox = function (self, form, field)
		if not field:label() then
			return ""
		end
		local id = self:_fieldId(field, form)
		if not id then
			return field:label()
		end
		return "<label for="..("%q"):format(html.escape(id))..">"..field:label():tr().."</label>"
	end;
	renderField = function (self, form, field)
		local html, js = field:asHtml(form)
		return html, (js or field:onLoad() and ((js or "")..(field:onLoad() or "")))
	end;
	renderFields = function (self, form)
		local html, js = ""
		-- Hidden fields first
		for _, v in ipairs(form:hiddenFields()) do
			html = html..self:renderField(form, v)
		end
		html = html..self._beforeFields
		-- Then visible fields
		for _, v in ipairs(form:visibleFields()) do
			local fieldHtml, fieldJs = self:renderField(form, v)
			if fieldJs then js = (js or "")..fieldJs end
			if v:widget():isA(widgets.Checkbox) then
				html = html..self._beforeLabel..self._afterLabel..self._beforeField..fieldHtml.." "..self:renderLabelCheckbox(form, v)..self._afterField
			else
				html = html..self._beforeLabel..self:renderLabel(form, v)..self._afterLabel..self._beforeField..fieldHtml..self._afterField
			end
		end
		-- Buttons
		html = html..self._beforeLabel..self._afterLabel..self._beforeField
		for _, v in ipairs(form:buttonFields()) do
			html = html..self:renderField(form, v)
		end
		return html..self._afterField..self._afterFields..(js and '<script type="text/javascript" language="JavaScript">//<![CDATA[\n'..js.."\n//]]></script>" or "")
	end;
	renderFormEnd = function (self, form)
		return "</form>"
	end;
	renderJs = function (self, form)
		local validationFunc = "function(){"
		for name, f in pairs(form:fields()) do
			for _, v in pairs(f:validators()) do
				local id = self:_fieldId(f, form)
				validationFunc = validationFunc.."if(!$('#"..id.."')."..v:js().."){$('#"..id.."').showError("..("%q"):format(v:errorMsg():format(f:label():tr():capitalize()))..");return false;}"
			end
		end
		validationFunc = validationFunc.."return true;}"
		local ajax = form:ajax()
		return '<script type="text/javascript" language="JavaScript">//<![CDATA[\n'
		..(ajax and ("var options="..("string" == type(ajax) and ajax or json.serialize(ajax))..";options.beforeSubmit="..validationFunc..';$("#'..form:htmlId()..'").ajaxForm(options);') or ('$("#'..form:htmlId()..'").submit('..validationFunc..");"))
		.."\n//]]></script>"
	end;
	render = function (self, form)
		return self:renderFormHeader(form)..self:renderFields(form)..self:renderFormEnd(form)..self:renderJs(form)
	end;
}

local FlowForm = Form:extend{
	__tag = .....".FlowForm";
	_beforeFields = "";
	_beforeLabel = " ";
	_afterLabel = " ";
	_beforeField = " ";
	_afterField = " ";
	_afterFields = "";
	init = function () end;
}

local HorisontalTableForm = Form:extend{
	__tag = .....".HorisontalTableForm";
	_beforeFields = "<table><tbody><tr>";
	_beforeLabel = "<th>";
	_afterLabel = "</th>";
	_beforeField = "<td>";
	_afterField = "</td>";
	_afterFields = "</tr></tbody></table>";
	init = function () end;
}

local VerticalTableForm = Form:extend{
	__tag = .....".HorisontalTableForm";
	_beforeFields = "<table><tbody>";
	_beforeLabel = "<tr><th>";
	_afterLabel = "</th>";
	_beforeField = "<td>";
	_afterField = "</td></tr>";
	_afterFields = "</tbody></table>";
	init = function () end;
}

return {
	Form=Form;FlowForm=FlowForm;HorisontalTableForm=HorisontalTableForm;
	VerticalTableForm=VerticalTableForm;
}
