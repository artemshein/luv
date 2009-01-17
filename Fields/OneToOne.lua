local Fields = from"Luv":import"Fields"

module(...)

return Fields.Reference:extend{
	__tag = "Fields.OneToOne",

	init = function (self, params)
		self:setParams(params)
	end,
	getTableName = function (self)
		if not self.tableName then
			local t1, t2 = self:getContainer():getTableName(), self:getRefModel():getTableName()
			if t1 > t2 then
				self.tableName = "o2o_"..t1.."_"..t2
			else
				self.tableName = "o2o_"..t2.."_"..t1
			end
			if role then
				self.tableName = self.tableName.."_"..role
			end
		end
		return self.tableName
	end,
	createBackLink = function (self)
		return Fields.OneToOne{references=self:getContainer()}
	end,
	createTable = function (self)
		local c = self:getContainer():getDb():createTable(self:getTableName())
		local containerTableName = self:getContainer():getTableName()
		local containerPk = self:getContainer():getPk()
		local refTableName = self:getRefModel():getTableName()
		local refPk = self:getRefModel():getPk()
		c:field(containerTableName, self:getContainer():getFieldTypeSql(containerPk), {required = true, null = false, unique = true})
		c:constraint(containerTableName, containerTableName, containerPk:getName())
		c:field(refTableName, self:getRefModel():getFieldTypeSql(refPk), {required = true, null = false, unique = true})
		c:constraint(refTableName, refTableName, refPk:getName())
		return c:exec()
	end,
	dropTable = function (self)
		return self:getContainer():getDb():dropTable(self:getTableName()):exec()
	end
}
