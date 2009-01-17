local require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert = require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert
local Struct, Table, Fields, String, Exception, Debug = from"Luv":import("Struct", "Table", "Fields", "String", "Exception", "Debug")

module(...)

local modelsEq = function (self, second)
	local pkValue = self:getPk():getValue()
	if pkValue == nil then
		return false
	end
	return pkValue == second:getPk():getValue()
end

return Struct:extend{
	__tag = ...,

	__tostring = function (self)
		return tostring(self:getPk():getValue())
	end,
	extend = function (self, ...)
		local new = Struct.extend(self, ...)
		-- Init fields
		rawset(new, "fields", new.fields or {})
		local hasPk, k, v = false
		for k, v in pairs(new) do
			if type(v) == "table" and v.isKindOf and v:isKindOf(Fields.Field) then
				new.fields[k] = v
				if v:isKindOf(Fields.Reference) then
					v:setContainer(new)
					if not v:getRelatedName() then
						if v:isKindOf(Fields.OneToMany) then
							v:setRelatedName(k)
						elseif v:isKindOf(Fields.ManyToOne) then
							Exception"Use OneToMany field on related model instead of ManyToOne!":throw()
						elseif v:isKindOf(Fields.ManyToMany) then
							v:setRelatedName(self:getLabelMany())
						else
							v:setRelatedName(self:getLabel())
						end
					end
					v:getRefModel():addField(v:getRelatedName(), v:createBackLink())
				end
				new[k] = nil
				hasPk = hasPk or v:isPk()
			end
		end
		if Table.isEmpty(new.fields) then
			Exception"Model must have at least one field!":throw()
		end
		if not hasPk then
			new.fields.id = Fields.Id()
		end
		if not new:getLabel() or not new:getLabelMany() then
			Exception"Label and labelMany must be defined!":throw()
		end
		return new
	end,
	init = function (self, values)
		if not self.fields then
			Exception"Abstract model can't be created (extend it first)!":throw()
		end
		local k, v, fields = nil, nil, {}
		for k, v in pairs(self.fields) do
			local field = v:clone()
			fields[k] = field
			if field:isKindOf(Fields.Reference) then
				field:setContainer(self)
			end
		end
		self.fields = fields
		if values then
			if type(values) == "table" then
				self:setValues(values)
			else
				self:getPk():setValue(values)
			end
		end
		getmetatable(self).__eq = modelsEq
	end,
	clone = function (self)
		local new, fields = Struct.clone(self), {}
		local k, v
		for k, v in pairs(self.fields) do
			fields[k] = v:clone()
		end
		new.fields = fields
		return new
	end,
	getPkName = function (self)
		local k, v
		for k, v in pairs(self.fields) do
			if v:isPk() then
				return k
			end
		end
		return nil
	end,
	addField = function (self, name, field)
		assert(field:isKindOf(Fields.Field), "Field expected!")
		self.fields[name] = field
		if field:isKindOf(Fields.Reference) then
			field:setContainer(self)
		end
	end,
	getPk = function (self)
		return self:getField(self:getPkName())
	end,
	getReferenceField = function (self, class, model)
		local k, v
		for k, v in pairs(self:getFields()) do
			if v:isKindOf(class) and model:isKindOf(v:getRefModel()) then
				return k
			end
		end
		return nil
	end,
	getDb = function (self) return self.db end,
	setDb = function (self, db) self.db = db return self end,
	getLabel = function (self) return self.label end,
	getLabelMany = function (self) return self.labelMany end,
	-- Set
	setValues = function (self, values)
		local k, v
		for k, v in pairs(self.fields) do
			v:setValue(values[k])
		end
	end,
	-- Find
	getFieldPlaceholder = function (self, field)
		if not field:isRequired() then
			return "?n"
		end
		if field:isKindOf(Fields.Char) then
			return "?"
		elseif field:isKindOf(Fields.Int) then
			return "?d"
		elseif field:isKindOf(Fields.ManyToOne) then
			return "?n"
		else
			Exception"Unsupported field type!":throw()
		end
	end,
	find = function (self, what)
		local new = self:new()
		local select = self.db:SelectRow():from(self:getTableName())
		local _, k, v
		if type(what) == "table" then
			for k, v in pairs(self.fields) do
				local value = what[k]
				if value then
					select:where("?#="..self:getFieldPlaceholder(v), k, value)
				end
			end
		else
			local pkName = self:getPkName()
			local pk = self:getField(pkName)
			select:where("?#="..self:getFieldPlaceholder(pk), pkName, what)
		end
		local res = select:exec()
		if not res then
			return nil
		end
		new:setValues(res)
		return new
	end,
	-- Save, insert, update, create
	insert = function (self)
		if not self:validate() then
			Exception"Validation error!":throw()
		end
		local insert = self:getDb():InsertRow():into(self:getTableName())
		local k, v
		for k, v in pairs(self.fields) do
			if not v:isKindOf(Fields.ManyToMany) and not v:isKindOf(Fields.OneToOne) and not v:isKindOf(Fields.OneToMany) then
				if v:isKindOf(Fields.ManyToOne) then
					local val = v:getValue()
					if val then
						val = val:getPk():getValue()
					end
					insert:set("?#="..self:getFieldPlaceholder(v), k, val)
				else
					insert:set("?#="..self:getFieldPlaceholder(v), k, v:getValue())
				end
			end
		end
		if not insert:exec() then
			return false
		end
		-- If Fields.Id than retrieve new generated ID
		local pk = self:getPk()
		if pk:isKindOf(Fields.Id) then
			pk:setValue(self.db:getLastInsertId())
		end
		-- Save references
		for k, v in pairs(self.fields) do
			if v:isKindOf(Fields.ManyToMany) then
				v:insert()
			end
		end
		return self
	end,
	update = function (self)
		if not self:validate() then
			Exception"Validation error!":throw()
		end
		local updateRow = self:getDb():UpdateRow(self:getTableName())
		local pkName, k, v = self:getPkName()
		local pk = self:getField(pkName)
		updateRow:where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue())
		for k, v in pairs(self.fields) do
			if not v:isKindOf(Fields.ManyToMany) and not v:isKindOf(Fields.OneToOne) and not v:isKindOf(Fields.OneToMany) and not v:isPk() then
				if v:isKindOf(Fields.ManyToOne) then
					local val = v:getValue()
					if val then
						val = val:getPk():getValue()
					end
					updateRow:set("?#="..self:getFieldPlaceholder(v), k, val)
				else
					updateRow:set("?#="..self:getFieldPlaceholder(v), k, v:getValue())
				end
			end
		end
		updateRow:exec()
		for k, v in pairs(self.fields) do
			if v:isKindOf(Fields.ManyToMany) then
				v:update()
			end
		end
	end,
	save = function (self)
		local pkName = self:getPkName()
		local pk = self:getField(pkName)
		if not pk:getValue() or not self:getDb():SelectCell(pkName):from(self:getTableName()):where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue()):exec() then
			return self:insert()
		else
			return self:update()
		end
	end,
	create = function (self, ...)
		local obj = self(...)
		if not obj:insert() then
			return nil
		end
		return obj
	end,
	-- Create and drop
	getTableName = function (self)
		if (not self.tableName) then
			self.tableName = self:getLabel()
		end
		if self.tableName then
			return self.tableName
		else
			Exception"Table name required!":throw()
		end
	end,
	setTableName = function (self, tableName) self.tableName = tableName return self end,
	getConstraintModels = function (self)
		local models, _, v = {}
		for _, v in pairs(self.fields) do
			if v:isKindOf(Fields.OneToMany) then
				Table.insert(models, v:getRef())
			end
		end
		return models
	end,
	getFieldTypeSql = function (self, field)
		if field:isKindOf(Fields.Char) then
			if field:getMaxLength() ~= 0 then
				return "VARCHAR("..field:getMaxLength()..")"
			else
				return "TEXT"
			end
		elseif field:isKindOf(Fields.Int) then
			return "INTEGER"
		elseif field:isKindOf(Fields.ManyToOne) then
			return self:getFieldTypeSql(field:getRefModel():getPk())
		else
			Exception"Unsupported field type!":throw()
		end
	end,
	createTables = function (self)
		local c = self.db:CreateTable(self:getTableName())
		-- Fields
		local _, k, v, hasPk = nil, nil, false
		for k, v in pairs(self.fields) do
			if not v:isKindOf(Fields.OneToMany) and not v:isKindOf(Fields.ManyToMany) and not v:isKindOf(Fields.OneToOne) then
				hasPk = hasPk or v:isPk()
				c:field(k, self:getFieldTypeSql(v), {
					primaryKey = v:isPk(),
					unique = v:isUnique(),
					null = not v:isRequired(),
					serial = v:isKindOf(Fields.Id)
				})
				if v:isKindOf(Fields.ManyToOne) then
					local onDelete
					if v:isRequired() then
						onDelete = "CASCADE"
					else
						onDelete = "SET NULL"
					end
					c:constraint(k, v:getTableName(), v:getRefModel():getPkName(), "CASCADE", onDelete)
				end
			end
		end
		if not c:exec() then
			return false
		end
		-- Create references tables
		for _, v in pairs(self.fields) do
			if v:isKindOf(Fields.ManyToMany) or v:isKindOf(Fields.OneToOne) then
				v:createTable()
			end
		end
	end,
	dropTables = function (self)
		local _, v
		for _, v in pairs(self.fields) do
			if v:isKindOf(Fields.ManyToMany) or v:isKindOf(Fields.OneToOne) then
				v:dropTable()
			end
		end
		return self.db:DropTable(self:getTableName()):exec()
	end
}
