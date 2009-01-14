local type, pairs = type, pairs
local Table, Reference, QuerySet = require"Table", require"Fields.Reference", require"LazyQuerySet"
local Debug = require"Debug"

module(...)

return Reference:extend{
	__tag = "Fields.ManyToMany",

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
			local t1, t2 = self:getContainer():getTableName(), self:getRefModel():getTableName()
			if t1 > t2 then
				self.tableName = "m2m_"..t1.."_"..t2
			else
				self.tableName = "m2m_"..t2.."_"..t1
			end
			local role = self:getRole()
			if role then
				self.tableName = self.tableName.."_"..role
			end
		end
		return self.tableName
	end,
	createTable = function (self)
		local container, refModel = self:getContainer(), self:getRefModel()
		local c = container:getDb():createTable(self:getTableName())
		local containerTableName = container:getTableName()
		local containerPkName = container:getPkName()
		local refTableName = refModel:getTableName()
		local refPkName = refModel:getPkName()
		c:field(containerTableName, container:getFieldTypeSql(container:getField(containerPkName)), {required = true, null = false})
		c:constraint(containerTableName, containerTableName, containerPkName)
		c:field(refTableName, refModel:getFieldTypeSql(refModel:getField(refPkName)), {required = true, null = false})
		c:constraint(refTableName, refTableName, refPkName)
		c:uniqueTogether(containerTableName, refTableName)
		return c:exec()
	end,
	dropTable = function (self)
		return self:getContainer():getDb():dropTable(self:getTableName()):exec()
	end,
	insert = function (self)
		if self.value then
			local container, refModel = self:getContainer(), self:getRefModel()
			if not container:getPk():getValue() then
				Exception"Primary key value must be set first!":throw()
			end
			if not Table.isEmpty(self.value) then
				local s, _, v = container:getDb():insert(container:getFieldPlaceholder(container:getPk())..", "..refModel:getFieldPlaceholder(refModel:getPk()), container:getTableName(), refModel:getTableName()):into(self:getTableName())
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
			container:getDb():delete():from(self:getTableName()):where("?#="..container:getFieldPlaceholder(container:getPk()), container:getTableName(), container:getPk():getValue()):exec()
			if not Table.isEmpty(self.value) then
				local s, _, v = container:getDb():insert(container:getFieldPlaceholder(container:getPk())..", "..refModel:getFieldPlaceholder(refModel:getPk()), container:getTableName(), refModel:getTableName()):into(self:getTableName())
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
		return QuerySet(self:getRefModel(), function (qs, s)
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
