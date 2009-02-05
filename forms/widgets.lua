require "luv.string"
local pairs, io, string = pairs, io, string
local Widget, widgets = require"luv".Widget, require"luv.fields.widgets"

module(...)

local Form = Widget:extend{
	__tag = .....".FormWidget",
	renderFormHeader = function (self, form)
		local id, action, method = "", "", [[ method="POST"]]
		if form:getId() then
			id = [[ id="]]..form:getId()..[["]]
		end
		action = [[ action="]]..(form:getAction() or "")..[["]]
		return "<form"..id..action..method..">"
	end,
	renderLabel = function (self, form, name, field)
		if not field:getLabel() then
			return ""
		end
		if not field:getId() then
			return string.capitalize(field:getLabel())..":"
		end
		return [[<label for="]]..field:getId().."_"..name..[[">]]..string.capitalize(field:getLabel())..[[</label>:]]
	end,
	renderField = function (self, form, name, field)
		return field:getWidget():render(name, field)
	end,
	renderFields = function (self, form)
		local html = ""
		local k, v
		-- Hidden fields first
		for k, v in pairs(form:getFields()) do
			if v:getWidget() and v:getWidget():isKindOf(widgets.HiddenInput) then
				html = html..self:renderField(k, v)
			end
		end
		html = html..self.beforeFields
		-- Then visible fields
		for k, v in pairs(form:getFields()) do
			if v:getWidget() and not v:getWidget():isKindOf(widgets.HiddenInput) and not v:getWidget():isKindOf(widgets.Button) then
				html = html..self.beforeLabel..self:renderLabel(form, k, v)..self.afterLabel..self.beforeField..self:renderField(form, k, v)..self.afterField
			end
		end
		-- Buttons
		html = html..self.beforeLabel..self.afterLabel..self.beforeField
		for k, v in pairs(form:getFields()) do
			if v:getWidget() and v:getWidget():isKindOf(widgets.Button) then
				html = html..self:renderField(form, k, v)
			end
		end
		return html..self.afterField..self.afterFields
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
