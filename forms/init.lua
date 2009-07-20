local table = require "luv.table"
local math, tostring = math, tostring
local require, rawset, type, pairs, ipairs, io = require, rawset, type, pairs, ipairs, io
local luv, fields, exceptions, models = require"luv", require"luv.fields", require"luv.exceptions", require"luv.db.models"
local references = require "luv.fields.references"
local Struct, Exception, Model = luv.Struct, exceptions.Exception, models.Model
local widgets = require "luv.fields.widgets"
local f = require "luv.function".f
local json = require "luv.utils.json"

module(...)

local Form = Struct:extend{
	__tag = .....".Form",
	extend = function (self, new)
		local new = Struct.extend(self, new)
		new:fields(table.map(self:fields() or {}, f "a:clone()"))
		-- Add self fields
		for k, v in pairs(new) do
			if type(v) == "table" and v.isA and v:isA(fields.Field) then
				new:addField(k, v)
				new[k] = nil
			end
		end
		return new
	end,
	init = function (self, values)
		Struct.init(self, values)
		if not self:fields() then
			Exception "abstract Form can't be created"
		end
		self.Meta = self.Meta or {}
		if not self.Meta.widget then
			self.Meta.widget = require"luv.forms.widgets".VerticalTableForm
		end
		self:setFields(table.map(self:fields(), f "a:clone()"))
		if values then
			if "table" == type(values) and values.isA and values:isA(Model) then
				self:values(values:values())
			else
				self:values(values)
			end
		end
	end;
	addField = function (self, name, f)
		if f:isA(references.OneToOne) or f:isA(references.ManyToOne) then
			if f:refModel():isA(models.NestedSet) then
				Struct.addField(self, name, fields.NestedSetSelect{label=f:label();choices=f:choices() or f:refModel():all();required=f:required()})
			else
				Struct.addField(self, name, fields.ModelSelect{label=f:label();choices=f:choices() or f:refModel():all();required=f:required()})
			end
		elseif f:isA(references.OneToMany) or f:isA(references.ManyToMany) then
			Struct.addField(self, name, fields.ModelMultipleSelect{label=f:label();choices=f:choices() or f:refModel():all();required=f:required()})
		else
			Struct.addField(self, name, f:clone())
		end
		return self
	end;
	getAction = function (self) return self.Meta.action or "" end,
	setAction = function (self, action) self.Meta.action = action return self end,
	getId = function (self)
		if not self.Meta.id then
			self:setId("f"..tostring(math.random(2000000000)))
		end
		return self.Meta.id
	end;
	setId = function (self, id) self.Meta.id = id return self end;
	getAjax = function (self) return self.Meta.ajax end;
	setAjax = function (self, ajax) self.Meta.ajax = ajax return self end;
	getWidget = function (self) return self.Meta.widget end,
	setWidget = function (self, widget) self.Meta.widget = widget return self end,
	isSubmitted = function (self, value)
		for name, f in pairs(self:getFields()) do
			if f:isKindOf(fields.ImageButton) and f:getValue() then
				return f:getValue()
			elseif f:isKindOf(fields.Submit) then
				local fVal = f:getValue()
				if ((value and (value == name)) or not value) and fVal == f:getDefaultValue() then
					return fVal
				end
			end
		end
		return false
	end,
	asHtml = function (self) return self.Meta.widget:render(self) end;
	__tostring = function (self) return self:asHtml() end;
	getFieldsList = function (self)
		if self.Meta.fields then
			return self.Meta.fields
		end
		local res = {}
		for name, _ in pairs(self:getFields()) do
			table.insert(res, name)
		end
		return res
	end;
	getHiddenFields = function (self)
		local res = {}
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
		local res = {}
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
		local res = {}
		for _, f in pairs(self:getFields()) do
			if f:isKindOf(fields.Button) then
				table.insert(res, f)
			end
		end
		return res
	end;
	getValues = function (self)
		local values = {}
		for name, f in pairs(self:getFields()) do
			local value = f:getValue()
			if f:isKindOf(fields.ModelMultipleSelect) then
				if "table" ~= type(value) then
					if value then
						value = {value}
					else
						value = {}
					end
				end
			end
			values[name] = value
		end
		return values
	end;
	setValues = function (self, values)
		for name, f in pairs(self:getFields()) do
			if f:isKindOf(fields.ImageButton) then
				f:setValue{x=values[name..".x"];y=values[name..".y"]}
			else
				f:setValue(values[name])
			end
		end
		return self
	end;
	-- Experimental
	processAjaxForm = function (self, action)
		if self:isSubmitted() then
			if self:isValid() and false ~= action(self) then
				io.write(json.serialize{result="ok";msgs=self:getMsgs()})
			else
				io.write(json.serialize{result="error";errors=self:getErrors()})
			end
		end
	end;
}

local ModelForm = Form:extend{
	__tag = .....".ModelForm";
	extend = function (self, new)
		new = Form.extend(self, new)
		if not new.Meta then
			Exception"Meta must be defined!"
		end
		if not new.Meta.model or not new.Meta.model.isKindOf or not new.Meta.model:isKindOf(Model) then
			Exception"Meta.model must be defined!"
		end
		for name, f in pairs(new.Meta.model:getFields()) do
			if f:isKindOf(fields.Button)
			or ((not new.Meta.fields or table.find(new.Meta.fields, name))
				and (not new.Meta.exclude or not table.find(new.Meta.exclude, name))) then
				new:addField(name, f)
			end
		end
		return new
	end;
	getModel = function (self) return self.Meta.model end;
	getPk = function (self) return self:getModel():getPk() end;
	getPkName = function (self) return self:getModel():getPkName() end;
	initModel = function (self, model)
		if not model or not model:isKindOf(self:getModel()) then
			Exception "instance of Meta.model expected"
		end
		for name, f in pairs(model:getFields()) do
			if (not self.Meta.fields or table.find(self.Meta.fields, name))
			and (not self.Meta.exclude or not table.find(self.Meta.exclude, name)) then
				model[name] = self[name]
			end
		end
	end;
	initForm = function (self, model)
		if not model or not model:isKindOf(self:getModel()) then
			Exception "instance of Meta.model expected"
		end
		for name, f in pairs(model:getFields()) do
			if (not self.Meta.fields or table.find(self.Meta.fields, name))
			and (not self.Meta.exclude or not table.find(self.Meta.exclude, name)) then
				if f:isKindOf(references.ManyToMany) or f:isKindOf(references.OneToMany) then
					self[name] = model[name]:all():getValue()
				else
					self[name] = model[name]
				end
			end
		end
	end;
}

return {Form=Form;ModelForm=ModelForm}
