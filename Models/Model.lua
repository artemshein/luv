local require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, Debug, type = require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, require"Debug", type
local Struct, Table, Reference, String = require"Struct", require"Table", require"Fields.Reference", require"String"
local ManyToMany, OneToMany, ManyToOne, OneToOne = require"Fields.ManyToMany", require"Fields.OneToMany", require"Fields.ManyToOne", require"Fields.OneToOne"

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
	-- Find
	getFieldPlaceholder = function (self, field)
		if not field:isRequired() then
			return "?n"
		end
		if field:isKindOf(require"Fields.Char") then
			return "?"
		elseif field:isKindOf(require"Fields.Int") then
			return "?d"
		elseif field:isKindOf(ManyToOne) then
			return "?n"
		else
			Exception:new"Unsupported field type!":throw()
		end
	end,
	find = function (self, what)
		local new = self:new()
		local select = self.db:selectRow():from(self:getTableName())
		local _, k, v
		if type(what) == "table" then
			for _, v in pairs(self.fields) do
				local name = v:getName()
				local value = what[name]
				if value then
					select:where("?#="..self:getFieldPlaceholder(v), name, value)
				end
			end
		else
			local pk = self:getPk()
			select:where("?#="..self:getFieldPlaceholder(pk), pk:getName(), what)
		end
		local res = select:exec()
		if not res then
			return nil
		end
		for k, v in pairs(res) do
			new[k] = v
		end
		return new
	end,
	-- Save, insert, update
	insert = function (self)
		local insert = self:getDb():insertRow():into(self:getTableName())
		local _, v
		for _, v in pairs(self.fields) do
			if not v:isKindOf(ManyToMany) and not v:isKindOf(OneToOne) and not v:isKindOf(OneToMany) then
				insert:set("?#="..self:getFieldPlaceholder(v), v:getName(), v:getValue())
			end
		end
		local res = insert:exec()
		if res then
			self:getPk():setValue(res)
		end
		return res
	end,
	update = function (self)
		local updateRow = self:getDb():updateRow(self:getTableName())
		local pk, _, v = self:getPk()
		updateRow:where("?#="..self:getFieldPlaceholder(pk), pk:getName(), pk:getValue())
		for _, v in pairs(self.fields) do
			if not v:isKindOf(ManyToMany) and not v:isKindOf(OneToOne) and not v:isKindOf(OneToMany) and not v:isPk() then
				updateRow:set("?#="..self:getFieldPlaceholder(v), v:getName(), v:getValue())
			end
		end
		return updateRow:exec()
	end,
	save = function (self)
		local pk = self:getPk()
		if not pk:getValue() or not self:getDb():selectCell(pk:getName()):from(self:getTableName()):where("?#="..self:getFieldPlaceholder(pk), pk:getName(), pk:getValue()):exec() then
			return self:insert()
		else
			return self:update()
		end
	end,
	-- Create and drop
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
			if v:isKindOf(OneToMany) then
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
		elseif field:isKindOf(require"Fields.Int") then
			return "INTEGER"
		elseif field:isKindOf(ManyToOne) then
			return self:getFieldTypeSql(field:getRefModel():getPk())
		else
			Exception:new"Unsupported field type!":throw()
		end
	end,
	create = function (self)
		local c = self.db:createTable(self:getTableName())
		-- Fields
		local _, v, hasPk = nil, nil, false
		for _, v in pairs(self.fields) do
			if not v:isKindOf(OneToMany) and not v:isKindOf(ManyToMany) and not v:isKindOf(OneToOne) then
				hasPk = hasPk or v:isPk()
				c:field(v:getName(), self:getFieldTypeSql(v), {
					primaryKey = v:isPk(),
					unique = v:isUnique(),
					null = not v:isRequired(),
					serial = v:isKindOf(require"Fields.Id")
				})
				if v:isKindOf(ManyToOne) then
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
			if v:isKindOf(ManyToMany) or v:isKindOf(OneToOne) then
				v:createTable()
			end
		end
	end,
	drop = function (self)
		local _, v
		for _, v in pairs(self.fields) do
			if v:isKindOf(ManyToMany) or v:isKindOf(OneToOne) then
				v:dropTable()
			end
		end
		return self.db:dropTable(self:getTableName()):exec()
	end
}
