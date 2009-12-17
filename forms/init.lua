local table = require "luv.table"
local math, tostring, select = math, tostring, select
local require, rawset, type, pairs, ipairs, io = require, rawset, type, pairs, ipairs, io
local luv, fields, exceptions, models = require"luv", require"luv.fields", require"luv.exceptions", require"luv.db.models"
local references = require "luv.fields.references"
local Struct, Exception, Model = luv.Struct, exceptions.Exception, models.Model
local widgets = require "luv.fields.widgets"
local json = require "luv.utils.json"

module(...)

local property = Struct.property

local Form = Struct:extend{
	__tag = .....".Form";
	__tostring = function (self) return self:asHtml() end;
	urlPrefix = property"string";
	htmlAction = property("string", function (self)
		if self:urlPrefix() then
			return self:urlPrefix()..self.Meta.action
		end
		return self.Meta.action
	end, "self.Meta.action");
	htmlId = property("string", function (self)
		if not self.Meta.id then
			self:htmlId("f"..tostring(math.random(2000000000)))
		end
		return self.Meta.id
	end, "self.Meta.id");
	ajax = property("string", "self.Meta.ajax", "self.Meta.ajax");
	widget = property(Widget, "self.Meta.widget", "self.Meta.widget");
	extend = function (self, new)
		local new = Struct.extend(self, new)
		new:fields(table.map(self:fields() or {}, "clone"))
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
			Exception"abstract Form can't be created"
		end
		self.Meta = self.Meta or {}
		if not self:widget() then
			self:widget(require"luv.forms.widgets".VerticalTable())
		end
		self:fields(table.map(self:fields(), "clone"))
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
				Struct.addField(self, name, fields.NestedSetSelect{
					label=f:label();required=f:required();hint=f:hint();
					choices=f:choices() or f:refModel():all();
				})
			else
				Struct.addField(self, name, fields.ModelSelect{
					label=f:label();required=f:required();hint=f:hint();
					choices=f:choices() or f:refModel():all();
				})
			end
		elseif f:isA(references.OneToMany) or f:isA(references.ManyToMany) then
			Struct.addField(self, name, fields.ModelMultipleSelect{
				label=f:label();required=f:required();hint=f:hint();
				choices=f:choices() or f:refModel():all();
			})
		else
			Struct.addField(self, name, f)
		end
		return self
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
			field = self:field(field) or Exception("field "..("%q"):format(field).." not founded")
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
			return true
		else
			return false
		end
	end;
}

local ModelForm = Form:extend{
	__tag = .....".ModelForm";
	formModel = property(Model, "self.Meta.model", "self.Meta.model");
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
			and (not new.Meta.exclude or not table.find(new.Meta.exclude, name)))
			and not new:field(name) then
				new:addField(name, f:clone())
			end
		end
		return new
	end;
	pkField = function (self) return self:formModel():pkField() end;
	pkName = function (self) return self:formModel():pkName() end;
	initModel = function (self, model)
		if not model or not model:isA(self:formModel()) then
			Exception"instance of Meta.model expected"
		end
		for name, f in pairs(model:fields()) do
			if (not self.Meta.fields or table.find(self.Meta.fields, name))
			and (not self.Meta.exclude or not table.find(self.Meta.exclude, name)) then
				model[name] = self[name]
			end
		end
	end;
	initForm = function (self, model)
		if "table" ~= type(model) or not model.isA or not model:isA(models.Model) then
			Exception"instance of Model expected"
		end
		if not model or not model:isA(self:formModel()) then
			Exception"instance of Meta.model expected"
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

-- Model improvements

models.Model.ajaxFieldForm = function (self, data)
	if not data or not data.field or not self:field(data.field) then
		return false
	end
	local f = Form:extend{
		id = self:pkField():clone();
		field = fields.Text{required=true};
		value = self:field(data.field):clone();
		set = fields.Submit{defaultValue="Set"};
		initModel = function (self, model)
			model[self.field] = self.value
		end;
	}(data)
	if not f:submitted() then
		return false
	end
	return f
end

models.Model.ajaxFieldHandler = function (self, data, preCond, postFunc)
	local f = self:ajaxFieldForm(data)
	if not f then
		return false
	end
	if not f:valid() then
		io.write(json.serialize{status="error";errors=f:errors()})
		return true
	end
	local obj = self:find(f.id)
	if not obj or (preCond and not preCond(f, obj)) then
		return false
	end
	f:initModel(obj)
	if not obj:update() then
		io.write(json.serialize{status="error";errors=f:errors()})
		return true
	end
	io.write(json.serialize{status="ok"})
	if postFunc then postFunc(f, obj) end
	return true
end


return {Form=Form;ModelForm=ModelForm}
