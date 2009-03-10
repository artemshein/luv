require "luv.string"
local type, require, pairs, table, select, string = type, require, pairs, table, select, string
local fields, Exception = require"luv.fields", require"luv.exceptions".Exception

module(...)

local MODULE = ...

local Reference = fields.Field:extend{
	__tag = .....".Reference",
	init = function (self, params)
		if self.parent.parent == fields.Field then
			Exception"Instantiate of abstract class is not allowed!":throw()
		end
		local Model = require "luv.db.models".Model
		if ("table" == type(params) and params.isObject and params:isKindOf(Model)) or "string" == type(params) then
			params = {references = params}
		end
		fields.Field.init(self, params)
	end,
	setParams = function (self, params)
		if type(params) == "table" then
			self.relatedName = params.relatedName
			self.toField = params.toField
			if not params.references then Exception"References required!":throw() end
			if "table" == type(params.references) then
				self.refModel = params.references
			else
				self.ref = params.references
			end
			fields.Field.setParams(self, params)
		else
			self.ref = params or Exception"References required!":throw()
		end
	end,
	getRelatedName = function (self) return self.relatedName end,
	setRelatedName = function (self, relatedName) self.relatedName = relatedName return self end,
	getToField = function (self) return self.toField end,
	getContainer = function (self) return self.container end,
	setContainer = function (self, container) self.container = container return self end,
	getRef = function (self) return self.ref end,
	getRole = function (self) return self.role end,
	setRole = function (self, role) self.role = role return self end,
	getRefModel = function (self)
		if not self.refModel then
			if not self.ref then
				Exception"References required!":throw()
			end
			self.refModel = require(self.ref)
		end
		return self.refModel
	end
}

local ManyToMany = Reference:extend{
	__tag = .....".ManyToMany",
	setValue = function (self, value)
		if "table" == type(value) then
			local refModel, _, v = self:getRefModel()
			for _, v in pairs(value) do
				if not v:isKindOf(refModel) then
					Exception"Table of field references instances required!":throw()
				end
			end
		end
		self.value = value
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
		return require(MODULE).ManyToMany{references=self:getContainer()}
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
				Exception"Primary key value must be set first!":throw()
			end
			if not table.isEmpty(self.value) then
				local s, _, v = container:getDb():Insert(container:getFieldPlaceholder(container:getPk())..", "..refModel:getFieldPlaceholder(refModel:getPk()), container:getTableName(), refModel:getTableName()):into(self:getTableName())
				for _, v in pairs(self.value) do
					s:values(container:getPk():getValue(), v:getPk():getValue())
				end
				s:exec()
			end
			self.value = nil
		end
	end,
	update = function (self)
		if self.value then
			local container, refModel = self:getContainer(), self:getRefModel()
			if not container:getPk():getValue() then
				Exception"Primary key value must be set first!":throw()
			end
			container:getDb():Delete():from(self:getTableName()):where("?#="..container:getFieldPlaceholder(container:getPk()), container:getTableName(), container:getPk():getValue()):exec()
			if not table.isEmpty(self.value) then
				local s, _, v = container:getDb():Insert(container:getFieldPlaceholder(container:getPk())..", "..refModel:getFieldPlaceholder(refModel:getPk()), container:getTableName(), refModel:getTableName()):into(self:getTableName())
				for _, v in pairs(self.value) do
					s:values(container:getPk():getValue(), v:getPk():getValue())
				end
				s:exec()
			end
			self.value = nil
		end
	end,
	getValue = function (self)
		return self
	end,
	all = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local pkName = container:getPkName()
		if not container:getField(pkName):getValue() then
			Exception"Primary key must be set first!":throw()
		end
		return require"luv.db.models".LazyQuerySet(self:getRefModel(), function (qs, s)
			s:join({refTable=self:getTableName()}, {"?#.?# = ?#.?#", "refTable", qs.model:getTableName(), qs.model:getTableName(), qs.model:getPkName()}, {})
			s:where("?#.?#="..qs.model:getFieldPlaceholder(container:getField(pkName)), "refTable", container:getTableName(), container:getField(pkName):getValue())
		end)
	end,
	count = function (self)
		return self:all():count()
	end,
	isEmpty = function (self)
		return 0 == self:count()
	end
}

local ManyToOne = Reference:extend{
	__tag = .....".ManyToOne",
	getValue = function (self)
		local valType = type(self.value)
		if valType ~= nil and valType ~= "table" then
			self:setValue(self:getRefModel():find(self.value))
		end
		return Reference.getValue(self)
	end,
	setValue = function (self, value)
		if type(value) == "table" and not value:isKindOf(self:getRefModel()) then
			Exception("Instance of "..self.ref.." or nil required!"):throw()
		elseif value ~= nil and type(value) ~= "table" and not self:getRefModel():getPk():isValid(value) then
			Exception"Invalid field value!":throw()
		end
		return Reference.setValue(self, value)
	end,
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	createBackLink = function (self)
		return require(MODULE).OneToMany{references=self:getContainer()}
	end
}

local getKeysForObjects = function (self, ...)
	local objKeys = {}
	for i = 1, select("#", ...) do
		local obj = select(i, ...)
		if type(obj) ~= "table" or not obj.isObject or not obj:isKindOf(self:getRefModel()) then
			Exception("Instance of "..self:getRef().." required!"):throw()
		end
		table.insert(objKeys, obj:getPk():getValue())
	end
	return objKeys
end

local OneToMany = Reference:extend{
	__tag = .....".OneToMany",
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	getValue = function (self)
		return self
	end,
	all = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local refFieldName = refModel:getReferenceField(require(MODULE).ManyToOne, container)
		if not refFieldName then
			Exception"Backwards reference field not founded!":throw()
		end
		local relationFieldName = refModel:getField(refFieldName):getToField() or container:getPkName()
		local relationField = container:getField(relationFieldName)
		if not relationField:getValue() then
			Exception"Relation field value must be set!":throw()
		end
		return require"luv.db.models".LazyQuerySet(refModel):filter{[refFieldName]=relationField:getValue()}
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
	pairs = function (self)
		return self:all():pairs()
	end,
	delete = function (self)
		return self:all():delete()
	end,
	update = function (self, ...)
		return self:all():update(...)
	end,
	add = function (self, ...)
		local refModel, model = self:getRefModel(), self:getContainer()
		local toFieldName = refModel:getReferenceField(require(MODULE).ManyToOne, model)
		if not toFieldName then
			Exception"Backwards reference field not founded!":throw()
		end
		local toFieldRelationFieldName = refModel:getField(toFieldName):getToField() or model:getPkName()
		local toFieldRelationField = model:getField(toFieldRelationFieldName)
		if not toFieldRelationField:getValue() then
			Exception"Relation field value must be set!":throw()
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
			Exception"Can't remove references with required property(you should delete it or set another value instead)!":throw()
		end
		return self:all():update{[toFieldName] = nil}
	end
}

local OneToOne = Reference:extend{
	__tag = .....".OneToOne",
	init = function (self, params)
		params = params or {}
		self:setParams(params)
		self.backLink = params.backLink
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
		return self:getRefModel():getReferenceField(require(MODULE).OneToOne, self:getContainer())
	end,
	isBackLink = function (self) return self.backLink end,
	createBackLink = function (self)
		return require(MODULE).OneToOne{references=self:getContainer(), backLink=true}
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
}

return {
	Reference = Reference,
	ManyToMany = ManyToMany,
	ManyToOne = ManyToOne,
	OneToMany = OneToMany,
	OneToOne = OneToOne
}
