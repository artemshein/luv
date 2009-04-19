require "luv.table"
require "luv.string"
require "luv.debug"
local os = os
local require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, table, string, debug, tonumber = require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, table, string, debug, tonumber
local math, ipairs, error, select = math, ipairs, error, select
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
	modelsList = {};
	__tostring = function (self) return tostring(self:getPk():getValue()) end,
	createBackLinksFieldsFrom = function (self, model)
		local _, v
		for _, v in ipairs(model:getReferenceFields(self)) do
			if not self:getField(v:getRelatedName() or Exception("relatedName required for "..v:getName().." field"):throw()) then
				self:addField(v:getRelatedName(), v:createBackLink())
			end
		end
	end;
	extend = function (self, ...)
		local new = Struct.extend(self, ...)
		-- Init fields
		rawset(new, "fields", new.fields or {})
		rawset(new, "fieldsByName", new.fieldsByName or {})
		local hasPk, k, v = false
		for k, v in pairs(new) do
			if type(v) == "table" and v.isObject and v:isKindOf(fields.Field) then
				new:addField(k, v)
				if not v:getLabel() then v:setLabel(k) end
				if v:isKindOf(references.Reference) then
					if not v:getRelatedName() then
						if v:isKindOf(references.OneToMany) then
							v:setRelatedName(k)
						elseif v:isKindOf(references.ManyToOne) then
							Exception"Use OneToMany field on related model instead of ManyToOne or set relatedName!":throw()
						elseif v:isKindOf(references.ManyToMany) then
							v:setRelatedName(new:getLabelMany() or Exception"LabelMany required!":throw())
						else
							v:setRelatedName(new:getLabel() or Exception"Label required!":throw())
						end
					end
					v:getRefModel():addField(v:getRelatedName(), v:createBackLink())
				end
				new[k] = nil
				hasPk = hasPk or v:isPk()
			end
		end
		if not table.isEmpty(new.fields) then
			if not hasPk then new:addField("id", fields.Id()) end
			local _
			for _, v in ipairs(self.modelsList) do
				new:createBackLinksFieldsFrom(v)
				v:createBackLinksFieldsFrom(new)
			end
			table.insert(self.modelsList, new)
		end
		new.Meta = new.Meta or {}
		return new
	end,
	init = function (self, values)
		Struct.init(self, values)
		if not self.fields then
			Exception"Abstract model can't be created (extend it first)!":throw()
		end
		local k, v, fields, fieldsByName = nil, nil, {}, {}
		for k, v in pairs(self:getFieldsByName()) do
			local field = v:clone()
			table.insert(fields, field)
			fieldsByName[k] = field
			if field:isKindOf(references.Reference) then
				field:setContainer(self)
			end
		end
		self.fields = fields
		self.fieldsByName = fieldsByName
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
		for k, v in pairs(self:getFieldsByName()) do
			fields[k] = v:clone()
		end
		new.fields = fields
		return new
	end,
	getPkName = function (self)
		local pk = self:getPk()
		if not pk then
			return nil
		end
		return pk:getName()
	end,
	getPk = function (self)
		local _, v
		for _, v in ipairs(self:getFields()) do
			if v:isPk() then
				return v
			end
		end
		return nil
	end,
	getReferenceFields = function (self, model, class)
		local res, _, v = {}
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.Reference) and  (not model or model:isKindOf(v:getRefModel())) and (not class or v:isKindOf(class)) then
				table.insert(res, v)
			end
		end
		return res
	end;
	getReferenceField = function (self, model, class)
		local _, v
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.Reference) and (not class or v:isKindOf(class)) and (not model or model:isKindOf(v:getRefModel())) then
				return v:getName()
			end
		end
		return nil
	end,
	getDb = function (self) return self.db end,
	setDb = function (self, db) rawset(self, "db", db) return self end,
	getLabel = function (self) return self.Meta.label or self.Meta.labels[1] end,
	getLabelMany = function (self) return self.Meta.labelMany or self.Meta.labels[2] end,
	-- Find
	getFieldPlaceholder = function (self, field)
		if not field:isRequired() then
			return "?n"
		end
		if field:isKindOf(fields.Text) or field:isKindOf(fields.Datetime) then
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
			for k, v in pairs(self:getFieldsByName()) do
				local value = what[k]
				if value then
					select:where("?#="..self:getFieldPlaceholder(v), k, value)
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
		new:setValues(res)
		return new
	end,
	all = function (self, limitFrom, limitTo)
		local qs = require "luv.db.models".LazyQuerySet(self)
		if limitFrom then
			qs:limit(limitFrom, limitTo)
		end
		return qs
	end;
	-- Save, insert, update, create
	insert = function (self)
		if not self:isValid() then
			--debug.dprint(self:getErrors())
			Exception"Validation error!":throw()
		end
		local insert = self:getDb():InsertRow():into(self:getTableName())
		for _, v in ipairs(self:getFields()) do
			if not v:isKindOf(references.ManyToMany) and not (v:isKindOf(references.OneToOne) and v:isBackLink()) and not v:isKindOf(references.OneToMany) then
				if v:isKindOf(references.ManyToOne) or v:isKindOf(references.OneToOne) then
					local val = v:getValue()
					if val then
						val = val:getField(v:getToField() or val:getPkName()):getValue()
					end
					insert:set("?#="..self:getFieldPlaceholder(v), v:getName(), val)
				else
					local val = v:getValue()
					if "nil" == type(val) then
						val = v:getDefaultValue()
					end
					if val and v:isKindOf(fields.Datetime) then
						val = os.date("%Y-%m-%d %H:%M:%S", val)
					end
					insert:set("?#="..self:getFieldPlaceholder(v), v:getName(), val)
				end
			end
		end
		if not insert:exec() then
			self:addError(self.db:getError())
			return false
		end
		-- If Fields.Id than retrieve new generated ID
		local pk = self:getPk()
		if pk:isKindOf(fields.Id) then
			pk:setValue(self.db:getLastInsertId())
		end
		-- Save references
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.ManyToMany) then
				v:insert()
			end
		end
		return true
	end,
	update = function (self)
		if not self:isValid() then
			Exception("Validation error! "..debug.dump(self:getErrors())):throw()
		end
		local updateRow = self:getDb():UpdateRow(self:getTableName())
		local pk, _, v = self:getPk()
		local pkName = pk:getName()
		updateRow:where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue())
		for _, v in ipairs(self:getFields()) do
			if not v:isKindOf(references.ManyToMany) and not (v:isKindOf(references.OneToOne) and v:isBackLink()) and not v:isKindOf(references.OneToMany) and not v:isPk() then
				if v:isKindOf(references.ManyToOne) or v:isKindOf(references.OneToOne) then
					local val = v:getValue()
					if val then
						val = val:getField(v:getToField() or val:getPkName()):getValue()
					end
					updateRow:set("?#="..self:getFieldPlaceholder(v), v:getName(), val)
				else
					local val = v:getValue()
					if "nil" == type(val) then
						val = v:getDefaultValue()
					end
					if val and v:isKindOf(fields.Datetime) then
						val = os.date("%Y-%m-%d %H:%M:%S", val)
					end
					updateRow:set("?#="..self:getFieldPlaceholder(v), v:getName(), val)
				end
			end
		end
		updateRow:exec()
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.ManyToMany) then
				v:update()
			end
		end
		return true
	end,
	save = function (self)
		local pk = self:getPk()
		local pkName = pk:getName()
		if not pk:getValue() or not self:getDb():SelectCell(pkName):from(self:getTableName()):where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue()):exec() then
			return self:insert()
		else
			return self:update()
		end
	end,
	delete = function (self)
		local pk = self:getPk()
		local pkName = pk:getName()
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
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.OneToMany) or (v:isKindOf(references.OneToOne) and not v:isBackLink()) then
				table.insert(models, v:getRefModel())
			end
		end
		return models
	end,
	getFieldTypeSql = function (self, field)
		if field:isKindOf(fields.Text) then
			if field:getMaxLength() ~= 0 and field:getMaxLength() < 65535 then
				return "VARCHAR("..field:getMaxLength()..")"
			else
				return "TEXT"
			end
		elseif field:isKindOf(fields.Boolean) then
			return "INT(1)"
		elseif field:isKindOf(fields.Int) then
			return "INT(4)"
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
		local _, v, hasPk = nil, nil, false
		for _, v in ipairs(self:getFields()) do
			if not v:isKindOf(references.OneToMany) and not v:isKindOf(references.ManyToMany) and not (v:isKindOf(references.OneToOne) and v:isBackLink()) then
				hasPk = hasPk or v:isPk()
				c:field(v:getName(), self:getFieldTypeSql(v), {
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
					c:constraint(v:getName(), v:getTableName(), v:getRefModel():getPkName(), "CASCADE", onDelete)
				end
			end
		end
		if not c:exec() then
			return false
		end
		-- Create references tables
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.ManyToMany) then
				v:createTable()
			end
		end
	end,
	dropTables = function (self)
		local _, v
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.ManyToMany) then
				v:dropTable()
			end
		end
		return self.db:DropTable(self:getTableName()):exec()
	end
}

local Tree = Model:extend{
	__tag = .....".Tree";
	hasChildren = Model.abstractMethod;
	getChildren = Model.abstractMethod;
	getParent = Model.abstractMethod;
	removeChildren = Model.abstractMethod;
	addChild = Model.abstractMethod;
	childrenCount = Model.abstractMethod;
	findRoot = Model.abstractMethod;
}

local NestedSet = Tree:extend{
	__tag = .....".NestedSet";
	hasChildren = function (self) return self.right-self.left > 1 end;
	getChildren = function (self)
		return self.parent:all():filter{left__gte=self.left;right__lte=self.right;level=self.level+1}:getValue()
	end;
	getParent = function (self)
		if 0 == self.level then
			return false
		end
		return self:find{left__le=self.left;right__ge=self.right;level=self.level-1}
	end;
	removeChildren = function (self)
		if not self:hasChildren() then
			return true
		end
		self.db:beginTransaction()
		self.db:Delete():from(self:getTableName())
			:where("?#>?d", "left", self.left)
			:andWhere("?#<?d", "right", self.right)
			:exec()
		self.db:Update(self:getTableName())
			:set("?#=?#-?d", "left", "left", self.right-self.left-1)
			:set("?#=?#-?d", "right", "right", self.right-self.left-1)
			:where("?#>?d", "left", self.right)
			:exec()
		self.right = self.left+1
		if not self:update() then
			self.db:rollback()
			return false
		end
		self.db:commit()
		return true
	end;
	addChild = function (self, child)
		if not child:isKindOf(self.parent) then Exception "not valid child class":throw() end
		child.level = self.level+1
		child.left = self.left+1
		child.right = self.left+2
		self.db:beginTransaction()
		self.db:Update(self:getTableName())
			:set("?#=?#+2", "left", "left")
			:where("?#>?d", "left", self.left)
			:exec()
		self.db:Update(self:getTableName())
			:set("?#=?#+2", "right", "right")
			:where("?#>?d", "right", self.left)
			:exec()
		if not child:insert() then
			self.db:rollback()
			return false
		end
		self.db:commit()
		return true
	end;
	childrenCount = function (self) return (self.right-self.left-1)/2 end;
	findRoot = function (self) return self:find{left=1} end;
	delete = function (self)
		self.db:beginTransaction()
		self.db:Delete():from(self:getTableName())
			:where("?#>?d", "left", self.left)
			:where("?#<?d", "right", self.right)
			:exec()
		Tree.delete(self)
		self.db:Update(self:getTableName())
			:set("?#=?#-?d", "left", "left", self.right-self.left+1)
			:where("?#>?d", "left", self.right)
			:exec()
		self.db:Update(self:getTableName())
			:set("?#=?#-?d", "right", "right", self.right-self.left+1)
			:where("?#>?d", "right", self.right)
			:exec()
		self.db:commit()
	end;
}

local LazyQuerySet = Object:extend{
	__tag = .....".LazyQuerySet",
	init = function (self, model, func)
		self.model = model
		self.db = model:getDb()
		self.evaluated = false
		self.filters = {}
		self.excludes = {}
		self.limits = {}
		self.orders = {}
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
	limit = function (self, limitFrom, limitTo)
		self.limits = {from=limitFrom;to=limitTo}
		return self
	end;
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
	order = function (self, ...)
		local i, v
		for i = 1, select("#", ...) do
			table.insert(self.orders, select(i, ...))
		end
		return self
	end;
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
				if name == "pk" then
					name = self.model:getPkName()
				end
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
		if self.limits.from then
			s:limit(self.limits.from, self.limits.to)
		end
		if not table.isEmpty(self.orders) then
			s:order(unpack(self.orders))
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
		if self.initFunc then self:initFunc(s) end
		self:applyFiltersAndExcludes(s)
		local _, v, obj = {}
		self.values = {}
		for _, v in ipairs(s:exec() or {}) do
			obj = self.model(v)
			table.insert(self.values, obj)
		end
	end,
	getValue = function (self)
		if not self.evaluated then
			self:evaluate()
		end
		return self.values
	end;
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
	Model = Model;Tree=Tree;NestedSet=NestedSet;
	LazyQuerySet = LazyQuerySet;
	Paginator=Paginator;
}
