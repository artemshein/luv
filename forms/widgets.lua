local pairs, io = pairs, io
local Widget, widgets = require"luv".Widget, require"luv.fields.widgets"

module(...)

local Form = Widget:extend{
	__tag = .....".FormWidget",
	renderFormHeader = function (self, form)
		local id, action, method = "", "", [[ method="POST"]]
		if form:getId() then
			id = [[ id="]]..form:getId()..[["]]
		end
		if form:getAction() then
			action = [[ action="]]..form:getAction()..[["]]
		end
		return "<form"..id..action..method..">"
	end,
	renderLabel = function (self, form, name, field)
		return [[<label for="]]..form:getId().."_"..name..[[">]]..field:getLabel()..[[</label>]]
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
			if v:getWidget() and not v:getWidget():isKindOf(widgets.HiddenInput) then
				html = html..self.beforeLabel..self:renderLabel(form, k, v)..self.afterLabel..self.beforeField..self:renderField(form, k, v)..self.afterField
			end
		end
		return html..self.afterFields
	end,
	renderFormEnd = function (self, form)
		return "</form>"
	end,
	render = function (self, form)
		return self:renderFormHeader(form)..self:renderFields(form)..self:renderFormEnd(form)
	end
}

local TableForm = Form:extend{
	__tag = .....".TableForm",
	beforeFields = "<table><tbody>",
	beforeLabel = "<th>",
	afterLabel = "</th>",
	beforeField = "<td>",
	afterField = "</td>",
	afterFields = "</tbody></table>"
}

return {
	Form = Form,
	TableForm = TableForm
}
