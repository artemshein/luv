local string = require "luv.string"
local debug = require "luv.debug"
local f = require 'luv.function'.f
local type, require, pairs, table, select, io, ipairs = type, require, pairs, table, select, io, ipairs
local fields, Exception = require"luv.fields", require"luv.exceptions".Exception
local widgets = require "luv.fields.widgets"

module(...)

local MODULE = ...

local Reference = fields.Field:extend{
	__tag = .....".Reference",
	init = function (self, params)
		if self.parent.parent == fields.Field then
			Exception"Instantiate of abstract class is not allowed!"
		end
		local Model = require "luv.db.models".Model
		if ("table" == type(params) and params.isObject and params:isKindOf(Model)) or "string" == type(params) then
			params = {references = params}
		end
		fields.Field.init(self, params)
	end,
	setParams = function (self, params)
		if "table" == type(params)  then
			self.toField = params.toField
			if "table" ~= type(params.references) then Exception "References must be a Model!" end
			self.refModel = params.references
			self.relatedName = params.relatedName
			fields.Field.setParams(self, params)
		else
			self.refModel = params or Exception"References required!"
		end
	end,
	getRelatedName = function (self) return self.relatedName end,
	setRelatedName = function (self, relatedName) self.relatedName = relatedName return self end,
	getToField = function (self) return self.toField end,
	getRole = function (self) return self.role end,
	setRole = function (self, role) self.role = role return self end,
	getRefModel = function (self) return self.refModel end;
}

local ManyToMany = Reference:extend{
	__tag = .....".ManyToMany",
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
	end;
	isValid = function (self)
		if self:isRequired() and #self:getValue() == 0 then
			return false
		end
		return Reference.isValid(self)
	end;
	setValue = function (self, value)
		if "table" ~= type(value) then
			value = nil
		else
			value = table.copy(value)
			if #value > 0 and "table" ~= type(value[1]) then
				value = self:getRefModel():all():filter{pk__in=value}:getValue()
			end
			--[[local refModel, k, v = self:getRefModel()
			for k, v in pairs(value) do
				if "table" ~= type(v) or not v.isObject or not v:isKindOf(refModel) then
					local obj = refModel:find(v)
					if not obj then
						Exception"Table of field references instances required!"
					else
						value[k] = obj
					end
				end
			end]]
		end
		self.value = value
		return self
	end,
	getTableName = function (self)
		if not self.tableName then
			local t1, t2 = string.replace(self:getContainer():getLabelMany(), " ", "_"), string.replace(self:getRefModel():getLabelMany(), " ", "_")
			if t1 < t2 then
				self.tableName = t1.."2"..t2
			else
				self.tableName = t2.."2"..t1
			end
			local role = self:getRole()
			if role then
				self.tableName = self.tableName.."_"..role
			end
		end
		return self.tableName
	end,
	createBackLink = function (self)
		return require(MODULE).ManyToMany{references=self:getContainer();relatedName=self:getName();label=self:getContainer():getLabelMany()}
	end,
	createTable = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local c = container:getDb():CreateTable(self:getTableName())
		local containerTableName = container:getTableName()
		local containerPkName = container:getPkName()
		local refTableName = refModel:getTableName()
		local refPkName = refModel:getPkName()
		c:field(containerTableName, container:getFieldTypeSql(container:getField(containerPkName)), {required=true, null=false})
		c:constraint(containerTableName, containerTableName, containerPkName)
		c:field(refTableName, refModel:getFieldTypeSql(refModel:getField(refPkName)), {required=true, null=false})
		c:constraint(refTableName, refTableName, refPkName)
		c:uniqueTogether(containerTableName, refTableName)
		return c:exec()
	end,
	dropTable = function (self)
		return self:getContainer():getDb():DropTable(self:getTableName()):exec()
	end,
	insert = function (self)
		if self.value then
			local container, refModel = self:getContainer(), self:getRefModel()
			if not container:getPk():getValue() then
				Exception"Primary key value must be set first!"
			end
			if not table.isEmpty(self.value) then
				local s = container:getDb():Insert(container:getFieldPlaceholder(container:getPk())..", "..refModel:getFieldPlaceholder(refModel:getPk()), container:getTableName(), refModel:getTableName()):into(self:getTableName())
				for _, v in pairs(self.value) do
					s:values(container:getPk():getValue(), v:getPk():getValue())
				end
				s:exec()
			end
			self.value = nil
		end
	end,
	add = function (self, values)
		local container, refModel = self:getContainer(), self:getRefModel()
		if not container:getPk():getValue() then
			Exception 'primary key value must be set first'
		end
		if 'table' ~= type(values) or values.isKindOf then
			values = {values}
		end
		local s = container:getDb():Insert(container:getFieldPlaceholder(container:getPk())..', '..refModel:getFieldPlaceholder(refModel:getPk()), container:getTableName(), refModel:getTableName()):into(self:getTableName())
		for _, v in ipairs(values) do
			s:values(container:getPk():getValue(), 'table' == type(v) and v:getPk():getValue() or tostring(v))
		end
		s:exec()
		self.value = nil
	end;
	update = function (self)
		if self.value then
			local container, refModel = self:getContainer(), self:getRefModel()
			if not container:getPk():getValue() then
				Exception"Primary key value must be set first!"
			end
			container:getDb():Delete():from(self:getTableName()):where("?#="..container:getFieldPlaceholder(container:getPk()), container:getTableName(), container:getPk():getValue()):exec()
			if "table" == type(self.value) and not table.isEmpty(self.value) then
				local s = container:getDb():Insert(container:getFieldPlaceholder(container:getPk())..", "..refModel:getFieldPlaceholder(refModel:getPk()), container:getTableName(), refModel:getTableName()):into(self:getTableName())
				for _, v in pairs(self.value) do
					s:values(container:getPk():getValue(), v:getPk():getValue())
				end
				s:exec()
			end
			self.value = nil
		end
	end,
	getValue = function (self)
		if not self.value and self:getContainer():getPk():getValue() then
			self:setValue(self:all():getValue())
		end
		return self.value
	end,
	remove = function (self, values)
		local container, refModel = self:getContainer(), self:getRefModel()
		container:getDb():Delete():from(self:getTableName())
			:where('?#='..container:getFieldPlaceholder(container:getPk()), container:getTableName(), container.pk)
			:where('?# IN (?a)', refModel:getTableName(), values)
			:exec()
		self.value = nil
	end;
	all = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		if not container.pk then
			return nil
		end
		local models = require 'luv.db.models'
		return models.QuerySet(refModel):filter{[self:getRelatedName().."__pk"]=container.pk}
	end,
	count = function (self)
		return self:all():count()
	end,
	isEmpty = function (self)
		return 0 == self:count()
	end;
	getRelatedName = function (self)
		if not self.relatedName then
			self.relatedName = self:getContainer():getLabelMany()
		end
		return Reference.getRelatedName(self)
	end;
}

local ManyToOne = Reference:extend{
	__tag = .....".ManyToOne",
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
	end;
	getValue = function (self)
		local valType = type(self.value)
		if self.value and valType ~= "table" then
			self:setValue(self:getRefModel():find(self.value))
		end
		return Reference.getValue(self)
	end,
	setValue = function (self, value)
		if type(value) == "table" and not value:isKindOf(self:getRefModel()) then
			Exception("Instance of "..self.ref.." or nil required!")
		elseif value ~= nil and value ~= '' and type(value) ~= "table" and not self:getRefModel():getPk():isValid(value) then
			debug.dprint(self)
			debug.dprint(value)
			Exception"Invalid field value!"
		end
		return Reference.setValue(self, value)
	end,
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	createBackLink = function (self)
		return require(MODULE).OneToMany{references=self:getContainer();relatedName=self:getName();label=self:getContainer():getLabelMany()}
	end;
	getRelatedName = function (self)
		if not self.relatedName then
			self.relatedName = string.replace(self:getContainer():getLabelMany(), ' ', '_')
		end
		return Reference.getRelatedName(self)
	end;
}

local getKeysForObjects = function (self, ...)
	local objKeys = {}
	for i = 1, select("#", ...) do
		local obj = select(i, ...)
		if type(obj) ~= "table" or not obj.isObject or not obj:isKindOf(self:getRefModel()) then
			Exception("Instance of "..self:getRef().." required!")
		end
		table.insert(objKeys, obj:getPk():getValue())
	end
	return objKeys
end

local OneToMany = Reference:extend{
	__tag = .....".OneToMany",
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
	end;
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	getValue = function (self)
		return self
	end,
	all = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local refFieldName = refModel:getReferenceField(container, require(MODULE).ManyToOne)
		if not refFieldName then
			Exception"Backwards reference field not founded!"
		end
		local relationFieldName = refModel:getField(refFieldName):getToField() or container:getPkName()
		local relationField = container:getField(relationFieldName)
		if not relationField:getValue() then
			Exception"Relation field value must be set!"
		end
		return require"luv.db.models".QuerySet(refModel):filter{[refFieldName.."__pk"]=container.pk}
	end,
	filter = function (self, ...)
		return self:all():filter(...)
	end,
	exclude = function (self, ...)
		return self:all():exclude(...)
	end,
	count = function (self)
		return self:all():count()
	end,
	delete = function (self)
		return self:all():delete()
	end,
	update = function (self, ...)
		return self:all():update(...)
	end,
	add = function (self, ...)
		local refModel, model = self:getRefModel(), self:getContainer()
		local toFieldName = refModel:getReferenceField(model, require(MODULE).ManyToOne)
		if not toFieldName then
			Exception"Backwards reference field not founded!"
		end
		local toFieldRelationFieldName = refModel:getField(toFieldName):getToField() or model:getPkName()
		local toFieldRelationField = model:getField(toFieldRelationFieldName)
		if not toFieldRelationField:getValue() then
			Exception"Relation field value must be set!"
		end
		local container = self:getContainer()
		local update, i = container:getDb():Update(self:getRefModel():getTableName())
		update:set("?#="..container:getFieldPlaceholder(refModel:getField(toFieldName)), toFieldName, toFieldRelationField:getValue())
		local refPkName = self:getRefModel():getPkName()
		update:where("?# IN (?a)", refPkName, getKeysForObjects(self, ...)):exec()
	end,
	remove = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local toFieldName = refModel:getReferenceField(require(MODULE).ManyToOne, container)
		if refModel:getField(toFieldName):isRequired() then
			Exception"Can't remove references with required property(you should delete it or set another value instead)!"
		end
		return self:all():update{[toFieldName] = nil}
	end;
	createBackLink = function (self)
		return require(MODULE).ManyToOne{references=self:getContainer();relatedName=self:getName();label=self:getContainer():getLabel()}
	end;
	getRelatedName = function (self)
		if not self.relatedName then
			self.relatedName = string.replace(self:getContainer():getLabel()' ', '_')
		end
		return Reference.getRelatedName(self)
	end;
}

local OneToOne = Reference:extend{
	__tag = .....".OneToOne",
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
		self.backLink = params.backLink or false
	end,
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	getValue = function (self)
		if self:isBackLink() then
			if not self.value and not self.loaded then
				self.loaded = true
				local backRefFieldName = self:getBackRefFieldName()
				local container = self:getContainer()
				local refModel = self:getRefModel()
				local val = container:getField(refModel:getField(backRefFieldName):getToField() or container:getPkName()):getValue()
				if val then
					self.value = self:getRefModel():find{[backRefFieldName] = val}
				end
			end
		else
			if self.value and "table" ~= type(self.value) then
				self.value = self:getRefModel():find(self.value)
			end
		end
		return self.value
	end,
	--[[getTableName = function (self)
		if not self.tableName then
			local t1, t2 = self:getContainer():getLabel(), self:getRefModel():getLabel()
			if t1 < t2 then
				self.tableName = t1.."2"..t2
			else
				self.tableName = t2.."2"..t1
			end
			if role then
				self.tableName = self.tableName.."_"..role
			end
		end
		return self.tableName
	end,]]
	getBackRefFieldName = function (self)
		return self:getRefModel():getReferenceField(self:getContainer(), require(MODULE).OneToOne)
	end,
	isBackLink = function (self) return self.backLink end,
	createBackLink = function (self)
		return require(MODULE).OneToOne{references=self:getContainer();backLink=not self:isBackLink();relatedName=self:getName();label=self:getContainer():getLabel()}
	end,
	--[[
	createTable = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local c = container:getDb():CreateTable(self:getTableName())
		local containerTableName = container:getTableName()
		local containerPkName = container:getPkName()
		local containerPk = container:getField(containerPkName)
		local refTableName = refModel:getTableName()
		local refPkName = refModel:getPkName()
		local refPk = refModel:getField(refPkName)
		c:field(containerTableName, container:getFieldTypeSql(containerPk), {required = true, null = false, unique = true})
		c:constraint(containerTableName, containerTableName, containerPkName)
		c:field(refTableName, refModel:getFieldTypeSql(refPk), {required = true, null = false, unique = true})
		c:constraint(refTableName, refTableName, refPkName)
		return c:exec()
	end,
	dropTable = function (self)
		return self:getContainer():getDb():DropTable(self:getTableName()):exec()
	end]]
	getRelatedName = function (self)
		if not self.relatedName then
			self.relatedName = self:getContainer():getLabel()
		end
		return Reference.getRelatedName(self)
	end;
}

return {
	Reference = Reference,
	ManyToMany = ManyToMany,
	ManyToOne = ManyToOne,
	OneToMany = OneToMany,
	OneToOne = OneToOne
}
