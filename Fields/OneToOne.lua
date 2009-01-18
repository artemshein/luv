local type = type
local Fields, Debug = from"Luv":import("Fields", "Debug")

module(...)

return Fields.Reference:extend{
	__tag = "Fields.OneToOne",

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
		return self:getRefModel():getReferenceField(Fields.OneToOne, self:getContainer())
	end,
	isBackLink = function (self) return self.backLink end,
	createBackLink = function (self)
		return Fields.OneToOne{references=self:getContainer(), backLink=true}
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
