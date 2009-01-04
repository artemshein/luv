local Struct, Table, Reference = require"Struct", require"Table", require"Fields.Reference"
local rawget, rawset, getmetatable, pairs = rawget, rawset, getmetatable, pairs

module(...)

return Struct:extend{
	__tag = "Models.Model",

	init = function (self)
		if not self.fields then
			Exception:new"Fields required!":throw()
		end
		local k, v, fields = nil, nil, {}
		for k, v in pairs(self.fields) do
			local field = v:clone()
			field:setName(k)
			field:setContainer(self)
			Table.insert(fields, field)
		end
		self.fields = fields
	end,
	clone = function (self)
		local new, fields = Struct.clone(self), {}
		local _, v
		for _, v in pairs(self.fields) do
			Table.insert(fields, v:clone())
		end
		new.fields = fields
		return new
	end,
	getDb = function (self) return self.db end,
	setDb = function (self, db) self.db = db return self end,
	getTableName = function (self)
		if (not self.tableName) then
			self.tableName = String.lower(String.slice(self.__tag, -String.findLast(self.__tag, ".")+1))
		end
		if self.tableName then
			return self.tableName
		else
			Exception:new"Table name required!":throw()
		end
	end,
	createTableSql = function (self)
		local c = self.db:createTable(self:getTableName())
		-- Fields
		local _, v
		for _, v in pairs(self:getFields()) do
			local type
			if v:isKindOf(require"Fields.Char") then
				if v:getMaxLength() ~= 0 then
					type = "VARCHAR("..v:getMaxLength()..")"
				else
					type = "TEXT"
				end
			elseif v:isKindOf(require"Fields.Int") or v:isKindOf(require"Fields.ManyToOne") then
				type = "INTEGER"
			else
				Exception:new"Unsupported field type!":throw()
			end
			c:field(v:getName(), type, {
				primaryKey = v:isPrimaryKey(),
				unique = v:isUnique(),
				null = v:isRequired(),
				serial = v:isKindOf(require"Fields.Id")
			})
		end
		return tostring(c)
	end
}
