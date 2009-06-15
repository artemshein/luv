local string = require "luv.string"
local tr = tr
local ipairs, io = ipairs, io
local Widget, widgets = require"luv".Widget, require"luv.fields.widgets"
local references = require "luv.fields.references"
local forms, fields, html = require "luv.forms", require "luv.fields", require "luv.utils.html"
local Exception = require "luv.exceptions".Exception

module(...)

function getId(form, field)
	return field:getId() or (form:getId()..string.capitalize(field:getName()))
end

local Form = Widget:extend{
	__tag = .....".FormWidget",
	renderFormHeader = function (self, form)
		local fileUploadFlag
		for _, f in ipairs(form:getFields()) do
			if f:getWidget():isKindOf(widgets.FileInput) then
				fileUploadFlag = true
			end
		end
		return
			'<form'
			..(form:getId() and (' id='..string.format('%q', form:getId())) or '')
			..' action='..string.format('%q', form:getAction() or '')
			..' method="POST"'
			..(fileUploadFlag and ' enctype="multipart/form-data"' or '')
			..'>'
	end,
	renderLabel = function (self, form, field)
		if not field:getLabel() then
			return ""
		end
		local id = getId(form, field)
		if not id then
			return string.capitalize(field:getLabel())..":"
		end
		return [[<label for="]]..html.escape(id)..[[">]]..string.capitalize(tr(field:getLabel()))..[[</label>:]]
	end;
	renderLabelCheckbox = function (self, form, field)
		if not field:getLabel() then
			return ""
		end
		local id = getId(form, field)
		if not id then
			return field:getLabel()
		end
		return [[<label for="]]..html.escape(id)..[[">]]..tr(field:getLabel())..[[</label>]]
	end;
	renderField = function (self, form, field)
		return field:asHtml(form)
	end,
	renderFields = function (self, form)
		local html, js = "", ""
		-- Hidden fields first
		for _, v in ipairs(form:getHiddenFields()) do
			html = html..self:renderField(form, v)
		end
		html = html..self.beforeFields
		-- Then visible fields
		for _, v in ipairs(form:getVisibleFields()) do
			local fieldHtml, fieldJs = self:renderField(form, v)
			if fieldJs then js = js..fieldJs end
			if v:getWidget():isKindOf(widgets.Checkbox) then
				html = html..self.beforeLabel..self.afterLabel..self.beforeField..fieldHtml.." "..self:renderLabelCheckbox(form, v)..self.afterField
			else
				html = html..self.beforeLabel..self:renderLabel(form, v)..self.afterLabel..self.beforeField..fieldHtml..self.afterField
			end
		end
		-- Buttons
		html = html..self.beforeLabel..self.afterLabel..self.beforeField
		for _, v in ipairs(form:getButtonFields()) do
			html = html..self:renderField(form, v)
		end
		return html..self.afterField..self.afterFields..(js and '<script type="text/javascript" language="JavaScript">//<![CDATA[\n'..js..'\n//]]></script>')
	end,
	renderFormEnd = function (self, form)
		return "</form>"
	end,
	render = function (self, form)
		return self:renderFormHeader(form)..self:renderFields(form)..self:renderFormEnd(form)
	end
}

local HorisontalTableForm = Form:extend{
	__tag = .....".HorisontalTableForm",
	beforeFields = "<table><tbody><tr>",
	beforeLabel = "<th>",
	afterLabel = "</th>",
	beforeField = "<td>",
	afterField = "</td>",
	afterFields = "</tr></tbody></table>"
}

local VerticalTableForm = Form:extend{
	__tag = .....".HorisontalTableForm",
	beforeFields = "<table><tbody>",
	beforeLabel = "<tr><th>",
	afterLabel = "</th>",
	beforeField = "<td>",
	afterField = "</td></tr>",
	afterFields = "</tbody></table>"
}

return {
	Form = Form,
	HorisontalTableForm = HorisontalTableForm,
	VerticalTableForm = VerticalTableForm
}
