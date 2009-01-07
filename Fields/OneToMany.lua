local require, Debug, tonumber, select, type = require, require"Debug", tonumber, select, type
local Table, Reference, Exception, QuerySet = require"Table", require"Fields.Reference", require"Exception", require"LazyQuerySet"

module(...)

return Reference:extend{
	__tag = "Fields.OneToMany",

	init = function (self, params)
		self:setParams(params)
	end,
	getTableName = function (self)
		return self:getRefModel():getTableName()
	end,
	getValue = function (self)
		return self
	end,
	count = function (self)
		local refModel, model = self:getRefModel(), self:getContainer()
		local toFieldName = refModel:getReferenceField(require"Fields.ManyToOne", model)
		if not toFieldName then
			Exception:new"Backwards reference field not founded!":throw()
		end
		local toFieldRelationFieldName = refModel:getField(toFieldName):getRelationField() or model:getPkName()
		local toFieldRelationField = model:getField(toFieldRelationFieldName)
		if not toFieldRelationField:getValue() then
			Exception:new"Relation field value must be set!":throw()
		end
		local s = model:getDb():selectCell("COUNT(*)"):from(refModel:getTableName())
		s:where("?#="..model:getFieldPlaceholder(toFieldRelationField), toFieldName, toFieldRelationField:getValue())
		local res = s:exec()
		if not res then
			return nil
		end
		return tonumber(res)
	end,
	add = function (self, ...)
		local refModel, model = self:getRefModel(), self:getContainer()
		local toFieldName = refModel:getReferenceField(require"Fields.ManyToOne", model)
		if not toFieldName then
			Exception:new"Backwards reference field not founded!":throw()
		end
		local toFieldRelationFieldName = refModel:getField(toFieldName):getRelationField() or model:getPkName()
		local toFieldRelationField = model:getField(toFieldRelationFieldName)
		if not toFieldRelationField:getValue() then
			Exception:new"Relation field value must be set!":throw()
		end
		local container = self:getContainer()
		local update, i = container:getDb():update(self:getRefModel():getTableName())
		update:set("?#="..container:getFieldPlaceholder(refModel:getField(toFieldName)), toFieldName, toFieldRelationField:getValue())
		local refPkName = self:getRefModel():getPkName()
		local objKeys = {}
		for i = 1, select("#", ...) do
			local obj = select(i, ...)
			if type(obj) ~= "table" or not obj.isKindOf or not obj:isKindOf(self:getRefModel()) then
				Exception:new("Instance of "..self:getRef().." required!"):throw()
			end
			Table.insert(objKeys, obj:getPk():getValue())
		end
		update:where("?# IN (?a)", refPkName, objKeys):exec()
	end
}
