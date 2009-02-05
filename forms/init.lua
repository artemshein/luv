require "luv.table"
local require, rawset, type, pairs, table = require, rawset, type, pairs, table
local luv, fields, exceptions, models = require"luv", require"luv.fields", require"luv.exceptions", require"luv.db.models"
local Struct, Exception, Model = luv.Struct, exceptions.Exception, models.Model

module(...)

local Form = Struct:extend{
	__tag = .....".Form",
	extend = function (self, new)
		local new = Struct.extend(self, new)
		local k, v
		rawset(new, "fields", {})
		-- Copy parent fields
		if self.fields then
			for k, v in pairs(self.fields) do
				new.fields[k] = v:clone()
			end
		end
		-- Add self fields
		for k, v in pairs(new) do
			if type(v) == "table" and v.isObject and v:isKindOf(fields.Field) then
				new.fields[k] = v
				new[k] = nil
				v:setId(k)
			end
		end
		return new
	end,
	init = function (self, values)
		if not self.fields then
			Exception"Abstract Form can't be created!":throw()
		end
		self.Meta = self.Meta or {}
		if not self.Meta.widget then
			self.Meta.widget = require"luv.forms.widgets".VerticalTableForm
		end
		local k, v
		for k, v in pairs(self.fields) do
			self.fields[k] = v:clone()
		end
		if values then
			if "table" == type(values) and values.isObject and values:isKindOf(Model) then
				self:setValues(values:getValues())
			else
				self:setValues(values)
			end
		end
	end,
	getAction = function (self) return self.Meta.action end,
	setAction = function (self, action) self.Meta.action = action return self end,
	getId = function (self) return self.Meta.id end,
	setId = function (self, id) self.Meta.id = id return self end,
	getWidget = function (self) return self.Meta.widget end,
	setWidget = function (self, widget) self.Meta.widget = widget return self end,
	asHtml = function (self) return self.Meta.widget:render(self) end,
	__tostring = function (self) return self:asHtml() end
}

local ModelForm = Form:extend{
	__tag = .....".ModelForm",
	extend = function (self, new)
		if not new.Meta then
			Exception"Meta must be defined!":throw()
		end
		if not new.Meta.model or not new.Meta.model.isObject or not new.Meta.model:isKindOf(Model) then
			Exception"Meta.model must be defined!":throw()
		end
		local k, v
		for k, v in pairs(new.Meta.model:getFields()) do
			if (not new.Meta.fields or table.find(new.Meta.fields, k))
				and (not new.Meta.exclude or not table.find(new.Meta.exclude, k)) then
				new[k] = v
			end
		end
		return Form.extend(self, new)
	end
}

return {
	Form = Form,
	ModelForm = ModelForm
}
