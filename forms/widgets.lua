local string = require "luv.string"
local tr, type = tr, type
local pairs, ipairs, io = pairs, ipairs, io
local Widget, widgets = require "luv".Widget, require "luv.fields.widgets"
local references = require "luv.fields.references"
local forms, fields, html = require "luv.forms", require "luv.fields", require "luv.utils.html"
local Exception = require "luv.exceptions".Exception
local json = require "luv.utils.json"

module(...)

local Form = Widget:extend{
	__tag = .....".FormWidget";
	_getFieldId = function (self, f, form)
		return f:getId() or (form:getId()..string.capitalize(f:getName()))
	end;
	_renderId = function (self, form)
		return form:getId() and (" id="..string.format("%q", form:getId())) or ""
	end;
	_renderAction = function (self, form)
		return " action="..string.format("%q", form:getAction() or "")
	end;
	renderFormHeader = function (self, form)
		local fileUploadFlag
		for _, f in ipairs(form:getFields()) do
			if f:getWidget():isKindOf(widgets.FileInput) then
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
		if not field:getLabel() then
			return ""
		end
		local id = self:_getFieldId(field, form)
		if not id then
			return string.capitalize(field:getLabel())..":"
		end
		return "<label for="..string.format("%q", html.escape(id))..">"..string.capitalize(tr(field:getLabel())).."</label>:"
	end;
	renderLabelCheckbox = function (self, form, field)
		if not field:getLabel() then
			return ""
		end
		local id = self:_getFieldId(field, form)
		if not id then
			return field:getLabel()
		end
		return "<label for="..string.format("%q", html.escape(id))..">"..tr(field:getLabel()).."</label>"
	end;
	renderField = function (self, form, field)
		local html, js = field:asHtml(form)
		return html, (js or field:getOnLoad() and ((js or "")..(field:getOnLoad() or "")))
	end;
	renderFields = function (self, form)
		local html, js = ""
		-- Hidden fields first
		for _, v in ipairs(form:getHiddenFields()) do
			html = html..self:renderField(form, v)
		end
		html = html..self._beforeFields
		-- Then visible fields
		for _, v in ipairs(form:getVisibleFields()) do
			local fieldHtml, fieldJs = self:renderField(form, v)
			if fieldJs then js = (js or "")..fieldJs end
			if v:getWidget():isKindOf(widgets.Checkbox) then
				html = html..self._beforeLabel..self._afterLabel..self._beforeField..fieldHtml.." "..self:renderLabelCheckbox(form, v)..self._afterField
			else
				html = html..self._beforeLabel..self:renderLabel(form, v)..self._afterLabel..self._beforeField..fieldHtml..self._afterField
			end
		end
		-- Buttons
		html = html..self._beforeLabel..self._afterLabel..self._beforeField
		for _, v in ipairs(form:getButtonFields()) do
			html = html..self:renderField(form, v)
		end
		return html..self._afterField..self._afterFields..(js and '<script type="text/javascript" language="JavaScript">//<![CDATA[\n'..js.."\n//]]></script>" or "")
	end;
	renderFormEnd = function (self, form)
		return "</form>"
	end;
	renderJs = function (self, form)
		local validationFunc = "function(){"
		for name, f in pairs(form:getFields()) do
			for _, v in pairs(f:getValidators()) do
				local id = self:_getFieldId(f, form)
				validationFunc = validationFunc.."if(!$('#"..id.."')."..v:getJs().."){$('#"..id.."').showError("..string.format("%q", string.format(v:getErrorMsg(), f:getLabel()))..");return false;}"
			end
		end
		validationFunc = validationFunc.."return true;}"
		local ajax = form:getAjax()
		return '<script type="text/javascript" language="JavaScript">//<![CDATA[\n'
		..(ajax and ("var options="..("string" == type(ajax) and ajax or json.serialize(ajax))..";options.beforeSubmit="..validationFunc..';$("#'..form:getId()..'").ajaxForm(options);') or ('$("#'..form:getId()..'").submit('..validationFunc..");"))
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
