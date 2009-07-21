local table = require "luv.table"
local math, tostring, select = math, tostring, select
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
		self:fields(table.map(self:fields(), f "a:clone()"))
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
	action = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.action = (select(1, ...))
			return self
		else
			return self.Meta.action or ""
		end
	end;
	id = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.id = (select(1, ...))
			return self
		else
			if not self.Meta.id then
				self:id("f"..tostring(math.random(2000000000)))
			end
			return self.Meta.id
		end
	end;
	ajax = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.ajax = (select(1, ...))
			return self
		else
			return self.Meta.ajax
		end
	end;
	widget = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.widget = (select(1, ...))
			return self
		else
			return self.Meta.widget
		end
	end;
	submitted = function (self, value)
		for name, f in pairs(self:fields()) do
			if f:isA(fields.ImageButton) and f:value() then
				return f:value()
			elseif f:isA(fields.Submit) then
				local fVal = f:value()
				if ((value and (value == name)) or not value) and fVal == f:defaultValue() then
					return fVal
				end
			end
		end
		return false
	end;
	asHtml = function (self) return self.Meta.widget:render(self) end;
	__tostring = function (self) return self:asHtml() end;
	fieldsList = function (self)
		if self.Meta.fields then
			return self.Meta.fields
		end
		local res = {}
		for name, _ in pairs(self:fields()) do
			table.insert(res, name)
		end
		return res
	end;
	hiddenFields = function (self)
		local res = {}
		for _, field in ipairs(self:fieldsList()) do
			field = self:field(field)
			local widget = field:widget()
			if widget and widget:isA(widgets.HiddenInput) then
				table.insert(res, field)
			end
		end
		return res
	end;
	visibleFields = function (self)
		local res = {}
		for _, field in ipairs(self:fieldsList()) do
			field = self:field(field)
			local widget = field:widget()
			if widget and not widget:isA(widgets.HiddenInput) and not widget:isA(widgets.Button) then
				table.insert(res, field)
			end
		end
		return res
	end;
	buttonFields = function (self)
		local res = {}
		for _, f in pairs(self:fields()) do
			if f:isA(fields.Button) then
				table.insert(res, f)
			end
		end
		return res
	end;
	values = function (self, ...)
		if select("#", ...) > 0 then
			local values = (select(1, ...))
			for name, f in pairs(self:fields()) do
				if f:isA(fields.ImageButton) then
					f:value{x=values[name..".x"];y=values[name..".y"]}
				else
					f:value(values[name])
				end
			end
			return self
		else
			local values = {}
			for name, f in pairs(self:fields()) do
				local value = f:value()
				if f:isA(fields.ModelMultipleSelect) then
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
		end
	end;
	-- Experimental
	processAjaxForm = function (self, action)
		if self:submitted() then
			if self:valid() and false ~= action(self) then
				io.write(json.serialize{result="ok";msgs=self:msgs()})
			else
				io.write(json.serialize{result="error";errors=self:errors()})
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
		if not new.Meta.model or not new.Meta.model.isA or not new.Meta.model:isA(Model) then
			Exception"Meta.model must be defined!"
		end
		for name, f in pairs(new.Meta.model:fields()) do
			if f:isA(fields.Button)
			or ((not new.Meta.fields or table.find(new.Meta.fields, name))
				and (not new.Meta.exclude or not table.find(new.Meta.exclude, name))) then
				new:addField(name, f)
			end
		end
		return new
	end;
	model = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.model = (select(1, ...))
			return self
		else
			return self.Meta.model
		end
	end;
	pk = function (self) return self:model():pk() end;
	pkName = function (self) return self:model():pkName() end;
	initModel = function (self, model)
		if not model or not model:isA(self:model()) then
			Exception "instance of Meta.model expected"
		end
		for name, f in pairs(model:fields()) do
			if (not self.Meta.fields or table.find(self.Meta.fields, name))
			and (not self.Meta.exclude or not table.find(self.Meta.exclude, name)) then
				model[name] = self[name]
			end
		end
	end;
	initForm = function (self, model)
		if not model or not model:isA(self:model()) then
			Exception "instance of Meta.model expected"
		end
		for name, f in pairs(model:fields()) do
			if (not self.Meta.fields or table.find(self.Meta.fields, name))
			and (not self.Meta.exclude or not table.find(self.Meta.exclude, name)) then
				if f:isA(references.ManyToMany) or f:isA(references.OneToMany) then
					self[name] = model[name]:all():value()
				else
					self[name] = model[name]
				end
			end
		end
	end;
}

return {Form=Form;ModelForm=ModelForm}
