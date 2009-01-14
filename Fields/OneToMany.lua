local require, Debug, tonumber, select, type, getmetatable = require, require"Debug", tonumber, select, type, getmetatable
local Table, Reference, Exception, QuerySet = require"Table", require"Fields.Reference", require"Exception", require"LazyQuerySet"

module(...)

local getKeysForObjects = function (self, ...)
	local objKeys = {}
	for i = 1, select("#", ...) do
		local obj = select(i, ...)
		if type(obj) ~= "table" or not obj.isKindOf or not obj:isKindOf(self:getRefModel()) then
			Exception("Instance of "..self:getRef().." required!"):throw()
		end
		Table.insert(objKeys, obj:getPk():getValue())
	end
	return objKeys
end

return Reference:extend{
	__tag = "Fields.OneToMany",

	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	getValue = function (self)
		return self
	end,
	all = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local refFieldName = refModel:getReferenceField(require"Fields.ManyToOne", container)
		if not refFieldName then
			Exception"Backwards reference field not founded!":throw()
		end
		local relationFieldName = refModel:getField(refFieldName):getRelationField() or container:getPkName()
		local relationField = container:getField(relationFieldName)
		if not relationField:getValue() then
			Exception"Relation field value must be set!":throw()
		end
		return QuerySet(refModel):filter{[refFieldName]=relationField:getValue()}
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
		local toFieldName = refModel:getReferenceField(require"Fields.ManyToOne", model)
		if not toFieldName then
			Exception"Backwards reference field not founded!":throw()
		end
		local toFieldRelationFieldName = refModel:getField(toFieldName):getRelationField() or model:getPkName()
		local toFieldRelationField = model:getField(toFieldRelationFieldName)
		if not toFieldRelationField:getValue() then
			Exception"Relation field value must be set!":throw()
		end
		local container = self:getContainer()
		local update, i = container:getDb():update(self:getRefModel():getTableName())
		update:set("?#="..container:getFieldPlaceholder(refModel:getField(toFieldName)), toFieldName, toFieldRelationField:getValue())
		local refPkName = self:getRefModel():getPkName()
		update:where("?# IN (?a)", refPkName, getKeysForObjects(self, ...)):exec()
	end,
	remove = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local toFieldName = refModel:getReferenceField(require"Fields.ManyToOne", container)
		if refModel:getField(toFieldName):isRequired() then
			Exception"Can't remove references with required property(you should delete it or set another value instead)!":throw()
		end
		return self:all():update{[toFieldName] = nil}
	end
}
