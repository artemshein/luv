local string = require"luv.string"
local tr, type, require, debug, table = tr, type, require, debug, table
local pairs, ipairs, io = pairs, ipairs, io
local Widget, widgets = require"luv".Widget, require"luv.fields.widgets"
local references = require"luv.fields.references"
local forms, fields, html = require"luv.forms", require"luv.fields", require"luv.utils.html"
local Exception = require"luv.exceptions".Exception
local json, html = require"luv.utils.json", require"luv.utils.html"

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
			return '<div class="fieldLabel">'..field:label()..":</div>"
		end
		return '<div class="fieldLabel"><label for='..("%q"):format(html.escape(id))..">"..field:label():tr():capitalize().."</label>:</div>"
	end;
	renderLabelCheckbox = function (self, form, field)
		if not field:label() then
			return ""
		end
		local id = self:_fieldId(field, form)
		if not id then
			return '<span class="fieldLabel">'..field:label().."</span"
		end
		return '<span class="fieldLabel"><label for='..("%q"):format(html.escape(id))..">"..field:label():tr().."</label></span>"
	end;
	renderField = function (self, form, field)
		local html, js = field:asHtml(form)
		local errors = field:errors()
		if errors and not table.empty(errors) then
			html = html..'<ul class="fieldErrors">'
			for _, error in ipairs(errors) do
				html = html.."<li>"..error.."</li>"
			end
			html = html.."</ul>"
		end
		return html, (js or field:onLoad() and ((js or "")..(field:onLoad() or "")))
	end;
	renderFields = function (self, form)
		local html, js = ""
		-- Hidden fields first
		for _, v in ipairs(form:hiddenFields()) do
			html = html..self:renderField(form, v)
		end
		html = html..self._beforeFields
		if "table" == type(form:fieldsList()[1]) then
			for _, fieldset in ipairs(form:fieldsList()) do
				html = html.."<fieldset title="..("%q"):format(fieldset.title:tr():capitalize()).."><legend>"..fieldset.title:tr():capitalize().."</legend>"
				for _, field in ipairs(fieldset.fields) do
					local v = form:field(field)
					local widget = v:widget()
					if widget and not widget:isA(widgets.HiddenInput) and not widget:isA(widgets.Button) then
						local fieldHtml, fieldJs = self:renderField(form, v)
						if fieldJs then js = (js or "")..fieldJs end
						if v:widget():isA(widgets.Checkbox) then
							html = html..self._beforeLabel..self._afterLabel..self._beforeField..fieldHtml.." "..self:renderLabelCheckbox(form, v)..self._afterField
						else
							html = html..self._beforeLabel..self:renderLabel(form, v)..self._afterLabel..self._beforeField..fieldHtml..self._afterField
						end
					end
				end
				html = html.."</fieldset>"
			end
		else
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
		end
		-- Buttons
		html = html..self._beforeButtons..self._beforeLabel..self._afterLabel..self._beforeField
		for _, v in ipairs(form:buttonFields()) do
			html = html..self:renderField(form, v)
		end
		return html..self._afterField..self._afterButtons..self._afterFields..(js and '<script type="text/javascript" language="JavaScript">//<![CDATA[\n'..js.."\n//]]></script>" or "")
	end;
	renderFormEnd = function (self, form)
		return "</form>"
	end;
	renderJs = function (self, form)
		local validationFunc = "function(){"
		for name, f in pairs(form:fields()) do
			for _, v in pairs(f:validators()) do
				local id = self:_fieldId(f, form)
				validationFunc = validationFunc.."if(!$('#"..id.."')."..v:js().."){$('#"..id.."').showError("..("%q"):format(v:errorMsg() % {field=f:label():tr():capitalize()})..");return false;}"
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

local Flow = Form:extend{
	__tag = .....".Flow";
	_beforeFields = "";
	_beforeLabel = " ";
	_afterLabel = " ";
	_beforeField = " ";
	_afterField = " ";
	_beforeButtons = '<div class="buttons">';
	_afterButtons = "</div>";
	_afterFields = "";
	init = function () end;
}

local HorisontalTable = Form:extend{
	__tag = .....".HorisontalTable";
	_beforeFields = "<table><tbody><tr>";
	_beforeLabel = "<th>";
	_afterLabel = "</th>";
	_beforeField = "<td>";
	_afterField = "</td>";
	_beforeButtons = "";
	_afterButtons = "";
	_afterFields = "</tr></tbody></table>";
	init = function () end;
}

local VerticalTable = Form:extend{
	__tag = .....".HorisontalTable";
	_beforeFields = "<table><tbody>";
	_beforeLabel = "<tr><th>";
	_afterLabel = "</th>";
	_beforeField = "<td>";
	_afterField = "</td></tr>";
	_beforeButtons = "";
	_afterButtons = "";
	_afterFields = "</tbody></table>";
	init = function () end;
}

return {
	Widget=Form;Flow=Flow;HorisontalTable=HorisontalTable;
	VerticalTable=VerticalTable;
}
