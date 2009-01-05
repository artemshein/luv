local require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, Debug = require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, require"Debug"
local Struct, Table, Reference, String = require"Struct", require"Table", require"Fields.Reference", require"String"

module(...)

local args = {...}

return Struct:extend{
	__tag = "Models.Model",

	extend = function (self, ...)
		local new = Struct.extend(self, ...)
		local hasPk, k, v = false
		if not new.fields then
			Exception:new"Model must have fields property!":throw()
		end
		for k,v in pairs(new.fields) do
			hasPk = hasPk or v:isPk()
			v:setName(k)
			v:setContainer(new)
		end
		if not hasPk then
			new.fields.id = require"Fields.Id":new()
		end
		return new
	end,
	init = function (self)
		if not self.fields then
			Exception:new"Fields required!":throw()
		end
		local _, v, fields = nil, nil, {}
		for _, v in pairs(self.fields) do
			local field = v:clone()
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
	getPk = function (self)
		local _, v
		for _, v in pairs(self.fields) do
			if v:isPk() then
				return v
			end
		end
		return nil
	end,
	getDb = function (self) return self.db end,
	setDb = function (self, db) self.db = db return self end,
	getTableName = function (self)
		if (not self.tableName) then
			self.tableName = String.lower(String.slice(self.__tag, String.findLast(self.__tag, ".")+1))
		end
		if self.tableName then
			return self.tableName
		else
			Exception:new"Table name required!":throw()
		end
	end,
	setTableName = function (self, tableName) self.tableName = tableName return self end,
	getConstraintModels = function (self)
		local models, _, v = {}
		for _, v in pairs(self.fields) do
			if v:isKindOf(require"Fields.OneToMany") then
				Table.insert(models, v:getRef())
			end
		end
		return models
	end,
	getFieldTypeSql = function (self, field)
		if field:isKindOf(require"Fields.Char") then
			if field:getMaxLength() ~= 0 then
				return "VARCHAR("..field:getMaxLength()..")"
			else
				return "TEXT"
			end
		elseif field:isKindOf(require"Fields.Int") or field:isKindOf(require"Fields.ManyToOne") then
			return "INTEGER"
		else
			Exception:new"Unsupported field type!":throw()
		end
	end,
	create = function (self)
		local c = self.db:createTable(self:getTableName())
		-- Fields
		local _, v, hasPk = nil, nil, false
		for _, v in pairs(self.fields) do
			if not v:isKindOf(require"Fields.OneToMany") and not v:isKindOf(require"Fields.ManyToMany") and not v:isKindOf(require"Fields.OneToOne") then
				hasPk = hasPk or v:isPk()
				c:field(v:getName(), self:getFieldTypeSql(v), {
					primaryKey = v:isPk(),
					unique = v:isUnique(),
					null = not v:isRequired(),
					serial = v:isKindOf(require"Fields.Id")
				})
				if v:isKindOf(require"Fields.ManyToOne") then
					local onDelete
					if v:isRequired() then
						onDelete = "CASCADE"
					else
						onDelete = "SET NULL"
					end
					c:constraint(v:getName(), v:getTableName(), v:getRefModel():getPk():getName(), "CASCADE", onDelete)
				end
			end
		end
		if not hasPk then
			c:field("id", "INTEGER", {
				primaryKey = true,
				null = false,
				serial = true
			})
		end
		if not c:exec() then
			return false
		end
		-- Create references tables
		for _, v in pairs(self.fields) do
			if v:isKindOf(require"Fields.ManyToMany") or v:isKindOf(require"Fields.OneToOne") then
				v:createTable()
			end
		end
	end,
	drop = function (self)
		local _, v
		for _, v in pairs(self.fields) do
			if v:isKindOf(require"Fields.ManyToMany") or v:isKindOf(require"Fields.OneToOne") then
				v:dropTable()
			end
		end
		return self.db:dropTable(self:getTableName()):exec()
	end
}
