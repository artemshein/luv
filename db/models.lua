require "luv.table"
require "luv.string"
require "luv.debug"
local require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, table, string, debug, tonumber = require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, table, string, debug, tonumber
local math = math
local Object, Struct, fields, references, Exception = require"luv.oop".Object, require"luv".Struct, require"luv.fields", require"luv.fields.references", require"luv.exceptions".Exception

module(...)

local modelsEq = function (self, second)
	local pkValue = self:getPk():getValue()
	if pkValue == nil then
		return false
	end
	return pkValue == second:getPk():getValue()
end

local Model = Struct:extend{
	__tag = .....".Model",
	__tostring = function (self)
		return tostring(self:getPk():getValue())
	end,
	extend = function (self, ...)
		local new = Struct.extend(self, ...)
		-- Init fields
		rawset(new, "fields", new.fields or {})
		local hasPk, k, v = false
		for k, v in pairs(new) do
			if type(v) == "table" and v.isObject and v:isKindOf(fields.Field) then
				new.fields[k] = v
				if not v:getLabel() then v:setLabel(k) end
				if v:isKindOf(references.Reference) then
					v:setContainer(new)
					if not v:getRelatedName() then
						if v:isKindOf(references.OneToMany) then
							v:setRelatedName(k)
						elseif v:isKindOf(references.ManyToOne) then
							Exception"Use OneToMany field on related model instead of ManyToOne or set relatedName!":throw()
						elseif v:isKindOf(references.ManyToMany) then
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
		if table.isEmpty(new.fields) then
			Exception"Model must have at least one field!":throw()
		end
		if not hasPk then
			new.fields.id = fields.Id()
		end
		if not new.Meta then
			Exception"Meta must be defined!":throw()
		end
		if new.Meta.labels then
			new.Meta.label = new.Meta.labels[1]
			new.Meta.labelMany = new.Meta.labels[2]
		end
		if not new:getLabel() or not new:getLabelMany() then
			Exception"Label and labelMany must be defined in Meta!":throw()
		end
		new.Admin = new.Admin or {}
		return new
	end,
	init = function (self, values)
		Struct.init(self, values)
		if not self.fields then
			Exception"Abstract model can't be created (extend it first)!":throw()
		end
		local k, v, fields = nil, nil, {}
		for k, v in pairs(self.fields) do
			local field = v:clone()
			fields[k] = field
			if field:isKindOf(references.Reference) then
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
		assert(field:isKindOf(fields.Field), "Field expected!")
		self.fields[name] = field
		if field:isKindOf(references.Reference) then
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
	setDb = function (self, db) rawset(self, "db", db) return self end,
	getLabel = function (self) return self.Meta.label end,
	getLabelMany = function (self) return self.Meta.labelMany end,
	-- Admin
	getSmallIcon = function (self) return self.Admin.smallIcon end;
	setSmallIcon = function (self, icon) self.Admin.smallIcon = icon return self end;
	getBigIcon = function (self) return self.Admin.bigIcon end;
	setBigIcon = function (self, icon) self.Admin.bigIcon = icon return self end;
	getCategory = function (self) return self.Admin.category end;
	setCategory = function (self, category) self.Admin.category = category return self end;
	getPath = function (self) return self.Admin.path or string.replace(string.lower(self:getLabelMany()), " ", "_") end;
	getDisplayList = function (self)
		if self.Admin.displayList then
			return self.Admin.displayList
		end
		local res, name, field = {}
		for name, _ in pairs(self:getFields()) do
			table.insert(res, name)
		end
		return res
	end;
	-- Find
	getFieldPlaceholder = function (self, field)
		if not field:isRequired() then
			return "?n"
		end
		if field:isKindOf(fields.Text) then
			return "?"
		elseif field:isKindOf(fields.Int) then
			return "?d"
		elseif field:isKindOf(references.ManyToOne) or field:isKindOf(references.OneToOne) then
			return "?n"
		else
			Exception"Unsupported field type!":throw()
		end
	end,
	find = function (self, what)
		local new = self()
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
	all = function (self)
		return require "luv.db.models".LazyQuerySet(self)
	end;
	-- Save, insert, update, create
	insert = function (self)
		if not self:isValid() then
			Exception"Validation error!":throw()
		end
		local insert = self:getDb():InsertRow():into(self:getTableName())
		local k, v
		for k, v in pairs(self.fields) do
			if not v:isKindOf(references.ManyToMany) and not (v:isKindOf(references.OneToOne) and v:isBackLink()) and not v:isKindOf(references.OneToMany) then
				if v:isKindOf(references.ManyToOne) or v:isKindOf(references.OneToOne) then
					local val = v:getValue()
					if val then
						val = val:getField(v:getToField() or val:getPkName()):getValue()
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
		if pk:isKindOf(fields.Id) then
			pk:setValue(self.db:getLastInsertId())
		end
		-- Save references
		for k, v in pairs(self.fields) do
			if v:isKindOf(references.ManyToMany) then
				v:insert()
			end
		end
		return self
	end,
	update = function (self)
		if not self:isValid() then
			Exception"Validation error!":throw()
		end
		local updateRow = self:getDb():UpdateRow(self:getTableName())
		local pkName, k, v = self:getPkName()
		local pk = self:getField(pkName)
		updateRow:where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue())
		for k, v in pairs(self.fields) do
			if not v:isKindOf(references.ManyToMany) and not (v:isKindOf(references.OneToOne) and v:isBackLink()) and not v:isKindOf(references.OneToMany) and not v:isPk() then
				if v:isKindOf(references.ManyToOne) or v:isKindOf(references.OneToOne) then
					local val = v:getValue()
					if val then
						val = val:getField(v:getToField() or val:getPkName()):getValue()
					end
					updateRow:set("?#="..self:getFieldPlaceholder(v), k, val)
				else
					updateRow:set("?#="..self:getFieldPlaceholder(v), k, v:getValue())
				end
			end
		end
		updateRow:exec()
		for k, v in pairs(self.fields) do
			if v:isKindOf(references.ManyToMany) then
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
	delete = function (self)
		local pkName = self:getPkName()
		local pk = self:getField(pkName)
		return self:getDb():DeleteRow():from(self:getTableName()):where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue()):exec()
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
			self.tableName = string.gsub(self:getLabel(), " ", "_")
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
			if v:isKindOf(references.OneToMany) then
				table.insert(models, v:getRef())
			end
		end
		return models
	end,
	getFieldTypeSql = function (self, field)
		if field:isKindOf(fields.Text) then
			if field:getMaxLength() ~= 0 then
				return "VARCHAR("..field:getMaxLength()..")"
			else
				return "TEXT"
			end
		elseif field:isKindOf(fields.Int) then
			return "INTEGER"
		elseif field:isKindOf(fields.Datetime) then
			return "DATETIME"
		elseif field:isKindOf(references.ManyToOne) or field:isKindOf(references.OneToOne) then
			return self:getFieldTypeSql(field:getRefModel():getField(field:getToField() or field:getRefModel():getPkName()))
		else
			Exception"Unsupported field type!":throw()
		end
	end,
	createTables = function (self)
		local c = self.db:CreateTable(self:getTableName())
		-- Fields
		local _, k, v, hasPk = nil, nil, false
		for k, v in pairs(self.fields) do
			if not v:isKindOf(references.OneToMany) and not v:isKindOf(references.ManyToMany) and not (v:isKindOf(references.OneToOne) and v:isBackLink()) then
				hasPk = hasPk or v:isPk()
				c:field(k, self:getFieldTypeSql(v), {
					primaryKey = v:isPk(),
					unique = v:isUnique(),
					null = not v:isRequired(),
					serial = v:isKindOf(fields.Id)
				})
				if v:isKindOf(references.ManyToOne) or v:isKindOf(references.OneToOne) then
					local onDelete
					if v:isRequired() or v:isPk() then
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
			if v:isKindOf(references.ManyToMany) then
				v:createTable()
			end
		end
	end,
	dropTables = function (self)
		local _, v
		for _, v in pairs(self.fields) do
			if v:isKindOf(references.ManyToMany) then
				v:dropTable()
			end
		end
		return self.db:DropTable(self:getTableName()):exec()
	end
}

local LazyQuerySet = Object:extend{
	__tag = .....".LazyQuerySet",
	init = function (self, model, func)
		self.model = model
		self.db = model:getDb()
		self.evaluated = false
		self.filters = {}
		self.excludes = {}
		self.initFunc = func
		getmetatable(self).__index = function (self, field)
			local res = self.parent[field]
			if res then
				return res
			end
			if not self.evaluated then
				self:evaluate()
				return self.values[field]
			end
			return nil
		end
	end,
	filter = function (self, filters)
		if type(filters) == "table" then
			table.insert(self.filters, filters)
		else
			table.insert(self.filters, {filters})
		end
		return self
	end,
	exclude = function (self, excludes)
		if type(excludes) == "table" then
			table.insert(self.excludes, excludes)
		else
			table.insert(self.excludes, {excludes})
		end
		return self
	end,
	applyFilterOrExclude = function (self, filter, s)
		local filTbl, k, v = {}
		for k, v in pairs(filter) do
			local op = "="
			if type(k) == "number" then
				k = self.model:getPkName()
			end
			if string.find(k, "__") then
				local vals = string.explode(k, "__")
				local name, op = vals[1], vals[2]
				if op == "exact" then
					table.insert(filTbl, self.db:processPlaceholders("?#="..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "lt" then
					table.insert(filTbl, self.db:processPlaceholders("?#<"..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "lte" then
					table.insert(filTbl, self.db:processPlaceholders("?#<="..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "gt" then
					table.insert(filTbl, self.db:processPlaceholders("?#>"..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "gte" then
					table.insert(filTbl, self.db:processPlaceholders("?#>="..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "in" then
					table.insert(filTbl, self.db:processPlaceholders("?# IN (?a)", name, v))
				elseif op == "beginswith" then
					table.insert(filTbl, self.db:processPlaceholders("?# LIKE ?", name, v.."%"))
				elseif op == "endswith" then
					table.insert(filTbl, self.db:processPlaceholders("?# LIKE ?", name, "%"..v))
				elseif op == "contains" then
					table.insert(filTbl, self.db:processPlaceholders("?# LIKE ?", name, "%"..v.."%"))
				else
					Exception("Operation "..op.." not supported!"):throw()
				end
			else
				table.insert(filTbl, self.db:processPlaceholders("?#="..self.model:getFieldPlaceholder(self.model:getField(k)), k, v))
			end
		end
		return table.join(filTbl, ") AND (")
	end,
	applyFiltersAndExcludes = function (self, s)
		local _, k, v, res
		for _, v in pairs(self.filters) do
			res = self:applyFilterOrExclude(v, s)
			if res ~= "" then
				s:where(res)
			end
		end
		for _, v in pairs(self.excludes) do
			res = self:applyFilterOrExclude(v, s)
			if res ~= "" then
				s:where("NOT ("..res..")")
			end
		end
		return s
	end,
	count = function (self)
		local s = self.db:SelectCell"COUNT(*)":from(self.model:getTableName())
		if self.initFunc then self:initFunc(s) end
		self:applyFiltersAndExcludes(s)
		return tonumber(s:exec())
	end,
	delete = function (self)
		local s = self.db:Delete():from(self.model:getTableName())
		if self.initFunc then self:initFunc(s) end
		self:applyFiltersAndExcludes(s)
		return s:exec()
	end,
	evaluate = function (self)
		self.evaluated = true
		local s = self.db:Select():from(self.model:getTableName())
		self:applyFiltersAndExcludes(s)
		local _, v, obj = {}
		self.values = {}
		for _, v in pairs(s:exec()) do
			obj = self.model(v)
			self.values[obj:getPk():getValue()] = obj
		end
	end,
	pairs = function (self)
		if not self.evaluated then
			self:evaluate()
		end
		return pairs(self.values)
	end,
	update = function (self, set)
		local s = self.db:Update(self.model:getTableName())
		if self.initFunc then self:initFunc(s) end
		self:applyFiltersAndExcludes(s)
		local k, v, val
		for k, v in pairs(set) do
			if type(v) == "table" and v.isKindOf and v:isKindOf(Model) then
				val = v:getPk():getValue()
			else
				val = v
			end
			s:set("?#="..self.model:getFieldPlaceholder(self.model:getField(k)), k, val)
		end
		s:exec()
	end
}

local Paginator = Object:extend{
	__tag = .....".Paginator";
	init = function (self, model, onPage)
		self.model = model
		self.onPage = onPage
		self.total = model:all():count()
	end;
	getModel = function (self) return self.model end;
	getOnPage = function (self) return self.onPage end;
	getTotal = function (self) return self.total end;
	getPage = function (self, page)
		return self.model:all((page-1)*self.onPage, page*self.onPage)
	end;
	getPagesTotal = function (self) return math.ceil(self.total/self.onPage) end;
}

return {
	Model = Model,
	LazyQuerySet = LazyQuerySet;
	Paginator=Paginator;
}
