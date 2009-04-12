require "luv.table"
require "luv.debug"
local math, tostring, debug = math, tostring, debug
local require, rawset, type, pairs, ipairs, table, io = require, rawset, type, pairs, ipairs, table, io
local luv, fields, exceptions, models = require"luv", require"luv.fields", require"luv.exceptions", require"luv.db.models"
local references = require "luv.fields.references"
local Struct, Exception, Model = luv.Struct, exceptions.Exception, models.Model
local widgets = require "luv.fields.widgets"

module(...)

local Form = Struct:extend{
	__tag = .....".Form",
	extend = function (self, new)
		local new = Struct.extend(self, new)
		local k, v
		rawset(new, "fields", {})
		rawset(new, "fieldsByName", {})
		-- Copy parent fields
		for k, v in pairs(self:getFieldsByName() or {}) do
			new:addField(k, v:clone())
		end
		-- Add self fields
		for k, v in pairs(new) do
			if type(v) == "table" and v.isObject and v:isKindOf(fields.Field) then
				new:addField(k, v)
				new[k] = nil
			end
		end
		return new
	end,
	init = function (self, values)
		Struct.init(self, values)
		if not self.fields then
			Exception"Abstract Form can't be created!":throw()
		end
		self.Meta = self.Meta or {}
		if not self.Meta.widget then
			self.Meta.widget = require"luv.forms.widgets".VerticalTableForm
		end
		local fieldsByName, k, v = self:getFieldsByName()
		rawset(self, "fields", {})
		rawset(self, "fieldsByName", {})
		for k, v in pairs(fieldsByName) do
			self:addField(k, v:clone())
		end
		if values then
			if "table" == type(values) and values.isObject and values:isKindOf(Model) then
				self:setValues(values:getValues())
			else
				self:setValues(values)
			end
		end
	end,
	getAction = function (self) return self.Meta.action or "" end,
	setAction = function (self, action) self.Meta.action = action return self end,
	getId = function (self)
		if not self.Meta.id then
			self:setId("f"..tostring(math.random(2000000000)))
		end
		return self.Meta.id
	end;
	setId = function (self, id) self.Meta.id = id return self end,
	getWidget = function (self) return self.Meta.widget end,
	setWidget = function (self, widget) self.Meta.widget = widget return self end,
	isSubmitted = function (self, value)
		local _, v
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(fields.Image) and v:getValue() then
				return v:getValue()
			elseif v:isKindOf(fields.Submit) then
				local fVal = v:getValue()
				if ((value and (value == v:getName())) or not value) and fVal == v:getDefaultValue() then
					return fVal
				end
			end
		end
		return false
	end,
	asHtml = function (self) return self.Meta.widget:render(self) end,
	__tostring = function (self) return self:asHtml() end;
	getFieldsList = function (self)
		if self.Meta.fields then
			return self.Meta.fields
		end
		local res, k, v = {}
		for k, v in pairs(self:getFieldsByName()) do
			table.insert(res, k)
		end
		return res
	end;
	getHiddenFields = function (self)
		local res, _, field = {}
		for _, field in ipairs(self:getFieldsList()) do
			field = self:getField(field)
			local widget = field:getWidget()
			if widget and widget:isKindOf(widgets.HiddenInput) then
				table.insert(res, field)
			end
		end
		return res
	end;
	getVisibleFields = function (self)
		local res, _, field = {}
		for _, field in ipairs(self:getFieldsList()) do
			field = self:getField(field)
			local widget = field:getWidget()
			if widget and not widget:isKindOf(widgets.HiddenInput) and not widget:isKindOf(widgets.Button) then
				table.insert(res, field)
			end
		end
		return res
	end;
	getButtonFields = function (self)
		local res, _, field = {}
		for _, field in ipairs(self:getFields()) do
			if field:isKindOf(fields.Button) then
				table.insert(res, field)
			end
		end
		return res
	end;
	getValues = function (self)
		local values, k, v = {}
		for k, v in pairs(self:getFieldsByName()) do
			local value = v:getValue()
			if v:isKindOf(fields.ModelMultipleSelect) then
				if "table" ~= type(value) then
					if value then
						value = {value}
					else
						value = {}
					end
				end
			end
			values[k] = value
		end
		return values
	end;
	setValues = function (self, values)
		local k, v
		for k, v in pairs(self:getFieldsByName()) do
			if v:isKindOf(fields.Image) then
				v:setValue{x=values[k..".x"];y=values[k..".y"]}
			else
				v:setValue(values[k])
			end
		end
		return self
	end;
}

local ModelForm = Form:extend{
	__tag = .....".ModelForm";
	extend = function (self, new)
		new = Form.extend(self, new)
		if not new.Meta then
			Exception"Meta must be defined!":throw()
		end
		if not new.Meta.model or not new.Meta.model.isObject or not new.Meta.model:isKindOf(Model) then
			Exception"Meta.model must be defined!":throw()
		end
		local k, v
		for k, v in pairs(new.Meta.model:getFieldsByName()) do
			if v:isKindOf(fields.Button)
			or ((not new.Meta.fields or table.find(new.Meta.fields, k))
				and (not new.Meta.exclude or not table.find(new.Meta.exclude, k))) then
				if v:isKindOf(references.OneToOne) or v:isKindOf(references.ManyToOne) then
					new:addField(k, fields.ModelSelect{values=v:getRefModel():all():getValue();required=v:isRequired()})
				elseif v:isKindOf(references.OneToMany) or v:isKindOf(references.ManyToMany) then
					new:addField(k, fields.ModelMultipleSelect{values=v:getRefModel():all():getValue();required=v:isRequired()})
				else
					new:addField(k, v:clone())
				end
			end
		end
		return new
	end;
	getModel = function (self) return self.Meta.model end;
	getPk = function (self) return self:getModel():getPk() end;
	getPkName = function (self) return self:getModel():getPkName() end;
}

return {
	Form = Form,
	ModelForm = ModelForm;
}
