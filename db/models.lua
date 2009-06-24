local table = require "luv.table"
local string = require "luv.string"
local os, debug = os, debug
local require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, tonumber = require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, tonumber
local math, ipairs, error, select = math, ipairs, error, select
local Object, Struct, fields, references, Exception = require"luv.oop".Object, require"luv".Struct, require"luv.fields", require"luv.fields.references", require"luv.exceptions".Exception
local cache, db = require "luv.cache.frontend", require "luv.db"
local crypt = require "luv.crypt"
local TreeNode = require "luv.utils".TreeNode
local f = require "luv.function".f

module(...)

local MODULE = ...

local function modelsEq (self, second)
	local pkValue = self:getPk():getValue()
	if pkValue == nil then
		return false
	end
	return pkValue == second:getPk():getValue()
end

local ModelTag = cache.Tag:extend{
	__tag = .....".ModelTag";
	init = function (self, backend, model)
		cache.Tag.init(self, backend, model:getTableName())
	end;
}

local ModelSlot = cache.Slot:extend{
	__tag = .....".ModelSlot";
	init = function (self, backend, model, id)
		cache.Slot.init(self, backend, model:getTableName().."_"..id)
		self:addTag(ModelTag(backend, model))
	end;
}

local ModelSqlSlot = cache.Slot:extend{
	__tag = .....".ModelSqlSlot";
	init = function (self, backend, model, sql)
		if not backend or not model or not sql then
			Exception "3 parameters expected!"
		end
		self.sql = sql
		cache.Slot.init(self, backend, tostring(crypt.Md5(tostring(sql))))
		self:addTag(ModelTag(backend, model))
	end;
	__call = function (self)
		return self:thru(self.sql)()
	end;
}

local Model = Struct:extend{
	__tag = .....".Model",
	modelsList = {};
	__tostring = function (self) return tostring(self:getPk():getValue()) end,
	createBackLinksFieldsFrom = function (self, model)
		for _, v in ipairs(model:getReferenceFields(self)) do
			if not self:getField(v:getRelatedName() or Exception("relatedName required for "..v:getName().." field")) then
				self:addField(v:getRelatedName(), v:createBackLink())
			end
		end
	end;
	extend = function (self, ...)
		local new = Struct.extend(self, ...)
		-- Init fields
		rawset(new, "fields", new.fields or {})
		rawset(new, "fieldsByName", new.fieldsByName or {})
		local hasPk = false
		for k, v in pairs(new) do
			if type(v) == "table" and v.isKindOf and v:isKindOf(fields.Field) then
				new:addField(k, v)
				if not v:getLabel() then v:setLabel(k) end
				if v:isKindOf(references.Reference) then
					if not v:getRelatedName() then
						if v:isKindOf(references.OneToMany) then
							v:setRelatedName(k)
						elseif v:isKindOf(references.ManyToOne) then
							Exception"Use OneToMany field on related model instead of ManyToOne or set relatedName!"
						elseif v:isKindOf(references.ManyToMany) then
							v:setRelatedName(new:getLabelMany() or Exception"LabelMany required!")
						else
							v:setRelatedName(new:getLabel() or Exception"Label required!")
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
			for _, v in ipairs(self.modelsList) do
				new:createBackLinksFieldsFrom(v)
				v:createBackLinksFieldsFrom(new)
			end
			table.insert(self.modelsList, new)
		end
		new.Meta = new.Meta or {}
		return new
	end;
	init = function (self, values)
		Struct.init(self, values)
		if not self.fields then
			Exception"Abstract model can't be created (extend it first)!"
		end
		local fields, fieldsByName = {}, {}
		for k, v in pairs(self:getFieldsByName()) do
			local field = v:clone()
			table.insert(fields, field)
			fieldsByName[k] = field
			field:setContainer(self)
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
		for _, v in ipairs(self:getFields()) do
			if v:isPk() then
				return v
			end
		end
		return nil
	end,
	getReferenceFields = function (self, model, class)
		local res = {}
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.Reference) and  (not model or model:isKindOf(v:getRefModel())) and (not class or v:isKindOf(class)) then
				table.insert(res, v)
			end
		end
		return res
	end;
	getReferenceField = function (self, model, class)
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
	getOrder = function (self) return self.Meta.order end;
	setOrder = function (self, order) self.Meta.order = order return self end;
	-- Find
	getFieldPlaceholder = function (self, field)
		if not field then
			Exception "field expected"
		end
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
			Exception"Unsupported field type!"
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
		local res = self:getCacher() and ModelSqlSlot(self:getCacher(), self, select)() or select()
		if not res then
			return nil
		end
		new:setValues(res)
		return new
	end,
	all = function (self, limitFrom, limitTo)
		local qs = require "luv.db.models".QuerySet(self)
		if limitFrom then
			qs:limit(limitFrom, limitTo)
		end
		local order = self:getOrder()
		if order then
			qs:order("table" == type(order) and unpack(order) or order)
		end
		return qs
	end;
	-- Save, insert, update, create
	insert = function (self)
		if not self:isValid() then
			local errors = self:getErrors()
			require "luv.dev".dprint(errors)
			Exception("Validation error!")
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
					if val then
						if v:isKindOf(fields.Datetime) then
							val = os.date("%Y-%m-%d %H:%M:%S", val)
						elseif v:isKindOf(fields.Date) then
							val = os.date("%Y-%m-%d", val)
						end
					end
					insert:set("?#="..self:getFieldPlaceholder(v), v:getName(), val)
				end
			end
		end
		if not insert() then
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
		self:clearCacheTag()
		return true
	end,
	update = function (self)
		if not self:isValid() then
			Exception("Validation error! "..debug.dump(self:getErrors()))
		end
		local updateRow = self:getDb():UpdateRow(self:getTableName())
		local pk = self:getPk()
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
					if val then
						if v:isKindOf(fields.Datetime) then
							val = os.date("%Y-%m-%d %H:%M:%S", val)
						elseif v:isKindOf(fields.Date) then
							val = os.date("%Y-%m-%d", val)
						elseif v:isKindOf(fields.Time) then
							val = os.date("%H:%M:%S", val)
						end
					end
					updateRow:set("?#="..self:getFieldPlaceholder(v), v:getName(), val)
				end
			end
		end
		updateRow()
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.ManyToMany) then
				v:update()
			end
		end
		self:clearCacheTag()
		return true
	end,
	save = function (self)
		local pk = self:getPk()
		local pkName = pk:getName()
		if not pk:getValue() or not self:getDb():SelectCell(pkName):from(self:getTableName()):where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue())() then
			return self:insert()
		else
			return self:update()
		end
	end,
	delete = function (self)
		local pk = self:getPk()
		local pkName = pk:getName()
		self:clearCacheTag()
		return self:getDb():DeleteRow():from(self:getTableName()):where("?#="..self:getFieldPlaceholder(pk), pkName, pk:getValue())()
	end,
	create = function (self, ...)
		local obj = self(...)
		if not obj:insert() then
			return nil
		end
		self:clearCacheTag()
		return obj
	end,
	-- Create and drop
	getId = function (self)
		return self:getTableName()..self.pk
	end;
	getTableName = function (self)
		if (not self.tableName) then
			self.tableName = string.gsub(self:getLabel(), " ", "_")
		end
		if self.tableName then
			return self.tableName
		else
			Exception"Table name required!"
		end
	end;
	setTableName = function (self, tableName) self.tableName = tableName return self end,
	getConstraintModels = function (self)
		local models = {}
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
		elseif field:isKindOf(fields.Date) then
			return "DATE"
		elseif field:isKindOf(fields.Time) then
			return "TIME"
		elseif field:isKindOf(references.ManyToOne) or field:isKindOf(references.OneToOne) then
			return self:getFieldTypeSql(field:getRefModel():getField(field:getToField() or field:getRefModel():getPkName()))
		else
			Exception"Unsupported field type!"
		end
	end,
	createTable = function (self)
		local c = self.db:CreateTable(self:getTableName())
		-- Fields
		local hasPk = false
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
		if not c() then
			return false
		end
	end;
	createTables = function (self)
		self:createTable()
		-- Create references tables
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.ManyToMany) then
				v:createTable()
			end
		end
	end,
	dropTable = function (self)
		self:clearCacheTag()
		return self.db:DropTable(self:getTableName())()
	end;
	dropTables = function (self)
		for _, v in ipairs(self:getFields()) do
			if v:isKindOf(references.ManyToMany) then
				v:dropTable()
			end
		end
		return self:dropTable()
	end;
	-- Caching
	getCacher = function (self) return self.cacher end;
	setCacher = function (self, cacher) self.cacher = cacher return self end;
	clearCacheTag = function (self)
		if self:getCacher() then
			ModelTag(self:getCacher(), self):clear()
		end
		return self
	end;
}

local Tree = Model:extend{
	__tag = .....".Tree";
	hasChildren = Model.abstractMethod;
	getChildren = Model.abstractMethod;
	getParent = Model.abstractMethod;
	removeChildren = Model.abstractMethod;
	addChild = Model.abstractMethod;
	addChildren = Model.abstractMethod;
	childrenCount = Model.abstractMethod;
	findRoot = Model.abstractMethod;
}

local NestedSet = Tree:extend{
	__tag = .....".NestedSet";
	hasChildren = function (self) return self.right-self.left > 1 end;
	getChildren = function (self)
		return self.parent:all():filter{left__gt=self.left;right__lt=self.right;level=self.level+1}:getValue()
	end;
	getParent = function (self)
		if 0 == self.level then
			return nil
		end
		-- TODO: rewrite to find{}
		return self.parent:all(1):filter{left__lt=self.left;right__gt=self.right;level=self.level-1}:getValue()[1]
	end;
	removeChildren = function (self)
		if not self:hasChildren() then
			return true
		end
		self.db:beginTransaction()
		self.db:Delete():from(self:getTableName())
			:where("?#>?d", "left", self.left)
			:andWhere("?#<?d", "right", self.right)()
		self.db:Update(self:getTableName())
			:set("?#=?#-?d", "left", "left", self.right-self.left-1)
			:set("?#=?#-?d", "right", "right", self.right-self.left-1)
			:where("?#>?d", "left", self.right)()
		self.right = self.left+1
		if not self:update() then
			self.db:rollback()
			return false
		end
		self.db:commit()
		return true
	end;
	addChild = function (self, child)
		if not child:isKindOf(self.parent) then Exception "not valid child class" end
		child.level = self.level+1
		child.left = self.left+1
		child.right = self.left+2
		self.db:beginTransaction()
		self.db:Update(self:getTableName())
			:set("?#=?#+2", "left", "left")
			:where("?#>?d", "left", self.left)()
		self.db:Update(self:getTableName())
			:set("?#=?#+2", "right", "right")
			:where("?#>?d", "right", self.left)()
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
			:where("?#<?d", "right", self.right)()
		Tree.delete(self)
		self.db:Update(self:getTableName())
			:set("?#=?#-?d", "left", "left", self.right-self.left+1)
			:where("?#>?d", "left", self.right)()
		self.db:Update(self:getTableName())
			:set("?#=?#-?d", "right", "right", self.right-self.left+1)
			:where("?#>?d", "right", self.right)()
		self.db:commit()
	end;
}

local F = TreeNode:extend{
	__tag = .....".F";
	init = function (self, ...)
		TreeNode.init(self, ...)
		local mt = getmetatable(self)
		mt.__add = function (self, f2)
			return self.parent({self;f2}, "+")
		end;
		mt.__sub = function (self, f2)
			return self.parent({self;f2}, "-")
		end;
		mt.__tostring = function (self)
			local function operandToString (op)
				if "string" == type(op) then
					return "?"
				elseif "number" == type(op) then
					return "?d"
				else
					return tostring(op)
				end
			end
			if not self:getConnector() then
				return "?#"
			elseif "+" == self:getConnector() then
				return operandToString(self:getChildren()[1]).."+"..operandToString(self:getChildren()[2])
			elseif "-" == self:getConnector() then
				return operandToString(self:getChildren()[1]).."-"..operandToString(self:getChildren()[2])
			else
				Exception("unsupported operand "..self:getConnector())
			end
		end;
	end;
	getValues = function (self)
		local function operandValues (op)
			if "string" == type(op) or "number" == type(op) then
				return {op}
			else
				return op:getValues()
			end
		end
		local connector = self:getConnector()
		local children = self:getChildren()
		if not connector then
			return {children[1]}
		elseif "+" == connector or "-" == connector then
			local res = operandValues(children[1])
			for _, v in ipairs(children[2]) do
				table.insert(res, v)
			end
			return res
		end
	end;
}

local Q = TreeNode:extend{
	__tag = .....".Q";
	init = function (self, values)
		TreeNode.init(self, {values}, "AND")
	end;
	isNegated = function (self) return self.negated end;
	__add = function (self, q)
		return self:clone():add(q, "AND")
	end;
	__sub = function (self, q)
		return self:clone():add(q, "OR")
	end;
	__unm = function (self)
		local obj = self:clone()
		obj.negated = obj.negated and false or true
		return obj
	end;
}

local QuerySet = Object:extend{
	__tag = .....".QuerySet";
	init = function (self, model)
		self._evaluated = false
		self._model = model
		self._orders = {}
		self._limits = {}
		self._values = {}
		self._query = model:getDb():Select "*":from(self._model:getTableName())
	end;
	clone = function (self)
		local obj = Object.clone(self)
		obj._orders = table.copy(obj._orders)
		obj._limits = table.copy(obj._limits)
		obj._values = table.copy(obj._values)
		obj._query = obj._query:clone()
		return obj
	end;
	filter = function (self, condition)
		local obj = self:clone()
		obj._evaluated = false
		obj._values = {}
		obj._q = obj._q and (obj._q + Q(condition)) or Q(condition)
		return obj
	end;
	exclude = function (self, condition)
		local obj = self:clone()
		obj._evaluated = false
		obj._values = {}
		obj._q = obj._q and (obj._q + -Q(condition)) or -Q(condition)
		return obj
	end;
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._orders, v)
		end
		return self
	end;
	limit = function (self, limitFrom, limitTo)
		self._limits = {from=limitFrom;to=limitTo}
		return self
	end;
	_processFieldName = function (self, s, parts)
		local curModel = self._model
		local result = {}
		for i, part in ipairs(parts) do
			if "pk" == part then
				part = curModel:getPkName()
			end
			local field = curModel:getField(part)
			if not curModel then
				Exception "invalid field"
			end
			if not field then
				Exception("field "..string.format("%q", part).." not founded")
			end
			if field:isKindOf(references.Reference) then
				result = {field:getRefModel():getTableName()}
				result.sql = "?#"
				if i == #parts then
					table.insert(result, field:getRefModel():getPkName())
					result.sql = result.sql..".?#"
				end
				if field:isKindOf(references.OneToOne) then
					if field:isBackLink() then
						s:join(
							field:getRefModel():getTableName(),
							{
								"?#.?#=?#.?#";
								curModel:getTableName();curModel:getPkName();
								field:getRefModel():getTableName();field:getBackRefFieldName()
							}
						)
					else
						s:join(
							field:getRefModel():getTableName(),
							{
								"?#.?#=?#.?#";
								curModel:getTableName();part;
								field:getRefModel():getTableName();field:getRefModel():getPkName()
							}
						)
					end
				elseif field:isKindOf(references.OneToMany) then
					s:join(
						field:getRefModel():getTableName(),
						{
							"?#.?#=?#.?#";
							curModel:getTableName();curModel:getPkName();
							field:getRefModel():getTableName();field:getRelatedName()
						}
					)
				elseif field:isKindOf(references.ManyToOne) then
					s:join(
						field:getRefModel():getTableName(),
						{"?#.?#=?#.?#";curModel:getTableName();part;field:getRefModel():getTableName();field:getRefModel():getPkName()}
					)
				elseif field:isKindOf(references.ManyToMany) then
					s:join(
						field:getTableName(),
						{
							"?#.?#=?#.?#";
							curModel:getTableName();curModel:getPkName();
							field:getTableName();curModel:getTableName()
						}
					)
					s:join(
						field:getRefModel():getTableName(),
						{
							"?#.?#=?#.?#";
							field:getTableName();field:getRefModel():getTableName();
							field:getRefModel():getTableName();field:getRefModel():getPkName()
						}
					)
				end
				curModel = field:getRefModel()
			else
				curModel = nil
				result.field = field
				result.sql = result.sql and (result.sql..".?#") or "?#"
				table.insert(result, part)
			end
		end
		return result
	end;
	_processFilter = function (self, s, filter)
		local operators = {
			eq="=";isnull=" IS NULL";exact="=";lt="<";gt=">";lte="<=";gte=">=";
			["in"]=" IN (?a)";beginswith=" LIKE ?";endswith=" LIKE ?";contains=" LIKE ?"
		}
		local result = {}
		if "string" == type(filter) then
			filter = {pk=filter}
		end
		for k, v in pairs(filter) do
			local parts
			if string.find(k, "__") then
				parts = string.explode(k, "__")
			else
				parts = {k}
			end
			local op = parts[table.maxn(parts)]
			if operators[op] then
				table.remove(parts)
			else
				op = "eq"
			end
			local res = self:_processFieldName(s, parts)
			local valStr, val
			if "isnull" == op or "in" == op or "beginswith" == op
			or "endswith" == op or "contains" == op then
				valStr = operators[op]
				if "beginswith" == op then
					v = v.."%"
				elseif "endswith" == op then
					v = "%"..v
				elseif "contains" == op then
					v ="%"..v.."%"
				elseif "isnull" == op then
					if not v then
						valStr = " IS NOT NULL"
					end
				end
			else
				valStr = operators[op]..self._model:getFieldPlaceholder(res.field)
			end
			result.sql = (result.sql and (result.sql.." AND ") or "")..res.sql..valStr
			for _, val in ipairs(res) do
				table.insert(result, val)
			end
			if "isnull" ~= op then
				table.insert(result, v)
			end
		end
		return result
	end;
	_processQ = function (self, s, q)
		local result = {}
		local op = q:getConnector()
		for _, v in ipairs(q:getChildren()) do
			local res = v.isKindOf and v:isKindOf(Q) and self:_processQ(s, v) or self:_processFilter(s, v)
			result.sql = (result.sql and (result.sql..op) or "")..res.sql
			for _, value in ipairs(res) do
				table.insert(result, value)
			end
		end
		result.sql = (q:isNegated() and "(NOT (" or "(")..result.sql..(q:isNegated() and "))" or ")")
		return result
	end;
	_applyConditions = function (self, s)
		if self._q then
			local res = self:_processQ(s, self._q)
			local values = {}
			for _, v in ipairs(res) do
				table.insert(values, v)
			end 
			s:where(string.slice(res.sql, 2, -2), unpack(values))
		end
		if self._limits.from then
			s:limit(self._limits.from, self._limits.to)
		end
		if not table.isEmpty(self._orders) then
			s:order(unpack(self._orders))
		end
	end;
	_evaluate = function (self)
		self._evaluated = true
		self:_applyConditions(self._query)
		self._values = {}
		for _, v in ipairs(self._query() or {}) do
			table.insert(self._values, self._model(v))
		end
	end;
	getValue = function (self)
		if not self._evaluated then
			self:_evaluate()
		end
		return self._values
	end;
	count = function (self)
		local s = self._model:getDb():SelectCell "COUNT(*)":from(self._model:getTableName())
		self:_applyConditions(s)
		return tonumber(s())
	end;
	asSql = function (self)
		local s = self._query:clone()
		self:_applyConditions(s)
		return tostring(s)
	end;
	update = function (self, set)
		local s = self._model:getDb():Select(self._model:getPkName()):from(self._model:getTableName())
		self:_applyConditions(s)
		local u = self._model:getDb():Update(self._model:getTableName()):where("?# IN (?a)", self._model:getPkName(), table.imap(s(), f ("a["..string.format("%q", self._model:getPkName()).."]")))
		local val
		for k, v in pairs(set) do
			if type(v) == "table" and v.isKindOf and v:isKindOf(Model) then
				val = v.pk
			else
				val = v
			end
			u:set("?#="..self._model:getFieldPlaceholder(self._model:getField(k)), k, val)
		end
		return u()
	end;
	delete = function (self)
		local s = self._model:getDb():Select(self._model:getPkName()):from(self._model:getTableName())
		self:_applyConditions(s)
		local u = self._model:getDb():Delete():from(self._model:getTableName()):where("?# IN (?a)", self._model:getPkName(), table.imap(s(), f ("a["..string.format("%q", self._model:getPkName()).."]")))
		return u()
	end;
	__call = function (self, ...)
		if not self._evaluated then
			self:_evaluate()
		end
		return ipairs(self._values, ...)
	end;
	__index = function (self, field)
		local res = self.parent[field]
		if res then
			return res
		end
		if "number" ~= type(field) then
			return nil
		end
		if not rawget(self, "_evaluated") then
			self:_evaluate()
		end
		return self._values[field]
	end;
}

local Paginator = Object:extend{
	__tag = .....".Paginator";
	init = function (self, model, onPage)
		self._model = model
		self._onPage = onPage
		self._query = model:all()
		self._total = self._query:count()
	end;
	getModel = function (self) return self._model end;
	getOnPage = function (self) return self._onPage end;
	getTotal = function (self) return self._total end;
	getPage = function (self, page)
		return self._query:limit((page-1)*self._onPage, page*self._onPage)
	end;
	getPagesTotal = function (self) return math.ceil(self._total/self._onPage) end;
	order = function (self, ...) self._query = self._query:order(...) return self end;
	filter = function (self, ...) self._query = self._query:filter(...) return self end;
	exclude = function (self, ...) self._query = self._query:exclude(...) return self end;
}

-- Tables

local function tablesListForModels (models)
	local tables = {}
	table.imap(models, function (model)
		local tableName = model:getTableName()
		for _, info in ipairs(tables) do
			if info[1] == tableName then
				return nil
			end
		end
		table.insert(tables, {model:getTableName();model})
		table.imap(model:getReferenceFields(nil, references.ManyToMany), function (field)
			local tableName = field:getTableName()
			for _, info in ipairs(tables) do
				if info[1] == tableName then
					return nil
				end
			end
			table.insert(tables, {field:getTableName();field})
			return nil
		end)
		return nil
	end)
	return tables
end

local function sortTablesList (tables)
	local size, i = #tables, 1
	while i < size do
		local iTbl, iObj = unpack(tables[i])
		for j = i+1, size do
			local jTbl, jObj = unpack(tables[j])
			if jObj:isKindOf(Model) then
				local o2o = jObj:getReferenceField(iObj, references.OneToOne)
				if jObj:getReferenceField(iObj, references.ManyToOne)
				or (o2o and not jObj:getField(o2o):isBackLink()) then
					tables[i], tables[j] = tables[j], tables[i]
					break
				end
			else
				if jObj:getRefModel():getTableName() == iTbl
				or jObj:getContainer():getTableName() == iTbl then
					tables[i], tables[j] = tables[j], tables[i]
					break
				end
			end
			if j == size then
				i = i+1
			end
		end
	end
	return tables
end

local function dropModels (models)
	for _, info in ipairs(sortTablesList(tablesListForModels(models))) do
		info[2]:dropTable()
	end
end

local function createModels (models)
	local tables = sortTablesList(tablesListForModels(models))
	for i = #tables, 1, -1 do
		tables[i][2]:createTable()
	end
end

return {
	Model=Model;ModelSlot=ModelSlot;ModelTag=ModelTag;Tree=Tree;NestedSet=NestedSet;
	QuerySet=QuerySet;Paginator=Paginator;F=F;
	tablesListForModels=tablesListForModels;sortTablesList=sortTablesList;
	dropModels=dropModels;createModels=createModels;
}
