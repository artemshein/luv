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
local json = require "luv.utils.json"

module(...)

local MODULE = ...

local ModelTag = cache.Tag:extend{
	__tag = .....".ModelTag";
	init = function (self, backend, model)
		cache.Tag.init(self, backend, model:tableName())
	end;
}

local ModelSlot = cache.Slot:extend{
	__tag = .....".ModelSlot";
	init = function (self, backend, model, id)
		cache.Slot.init(self, backend, model:tableName().."_"..id)
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
	__tag = .....".Model";
	modelsList = {};
	__tostring = function (self) return tostring(self.pk) end;
	cacher = Object.property;
	ajaxUrl = Object.property;
	createBackLinksFieldsFrom = function (self, model)
		for _, v in ipairs(model:referenceFields(self)) do
			if not self:field(v:relatedName() or Exception("relatedName required for "..v:name().." field")) then
				self:addField(v:relatedName(), v:createBackLink())
			end
		end
	end;
	extend = function (self, ...)
		local new = Struct.extend(self, ...)
		-- Init fields
		new:fields{}
		local hasPk = false
		for k, v in pairs(new) do
			if type(v) == "table" and v.isA and v:isA(fields.Field) then
				new:addField(k, v)
				if not v:label() then v:label(k) end
				if v:isA(references.Reference) then
					if not v:relatedName() then
						if v:isA(references.OneToMany) then
							v:relatedName(k)
						elseif v:isA(references.ManyToOne) then
							Exception"Use OneToMany field on related model instead of ManyToOne or set relatedName!"
						elseif v:isA(references.ManyToMany) then
							v:relatedName(new:labelMany() or Exception"LabelMany required!")
						else
							v:relatedName(new:label() or Exception"Label required!")
						end
					end
					v:refModel():addField(v:relatedName(), v:createBackLink())
				end
				new[k] = nil
				hasPk = hasPk or v:pk()
			end
		end
		if not table.isEmpty(new:fields()) then
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
		local classFields = self:fields()
		if not classFields then
			Exception "abstract model can't be created (extend it first)"
		end
		self:fields(table.map(classFields, f "a:clone()"))
		if values then
			if type(values) == "table" then
				self:values(values)
			else
				self:pkField():value(values)
			end
		end
	end;
	clone = function (self)
		local new = Struct.clone(self)
		new:fields(table.map(self:fields(), f "a:clone()"))
		return new
	end;
	__eq = function (self, second)
		local pkValue = self.pk
		if pkValue == nil then
			return false
		end
		return pkValue == second.pk
	end;
	pkName = function (self)
		local pk = self:pkField()
		if not pk then
			return nil
		end
		return pk:name()
	end;
	pk = function (self)
		for _, f in pairs(self:fields()) do
			if f:pk() then
				return f
			end
		end
		return nil
	end;
	referenceFields = function (self, model, class)
		local res = {}
		for _, f in pairs(self:fields()) do
			if f:isA(references.Reference) and  (not model or model:isA(f:refModel())) and (not class or f:isA(class)) then
				table.insert(res, f)
			end
		end
		return res
	end;
	referenceField = function (self, model, class)
		for name, f in pairs(self:fields()) do
			if f:isA(references.Reference) and (not class or f:isA(class)) and (not model or model:isA(f:refModel())) then
				return name
			end
		end
		return nil
	end;
	db = function (self, ...)
		if select("#", ...) > 0 then
			rawset(self, "_db", (select(1, ...)))
			return self
		else
			return self._db
		end
	end;
	label = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.label = (select(1, ...))
			return self
		else
			return self.Meta.label or self.Meta.labels[1]
		end
	end;
	labelMany = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.label = (select(1, ...))
			return self
		else
			return self.Meta.labelMany or self.Meta.labels[2]
		end
	end;
	order = function (self, ...)
		if select("#", ...) > 0 then
			self.Meta.order = (select(1, ...))
			return self
		else
			return self.Meta.order
		end
	end;
	-- Find
	fieldPlaceholder = function (self, field)
		if not field then
			Exception "field expected"
		end
		if not field.isA then
			field = self:field(field)
		end
		if not field or not field.isA or not field:isA(fields.Field) then
			Exception "field required"
		end
		if not field:required() then
			return "?n"
		end
		if field:isA(fields.Text) or field:isA(fields.Datetime) then
			return "?"
		elseif field:isA(fields.Int) then
			return "?d"
		elseif field:isA(references.ManyToOne) or field:isA(references.OneToOne) then
			return "?n"
		else
			Exception"Unsupported field type!"
		end
	end;
	find = function (self, what)
		local new = self()
		local select = self._db:SelectRow():from(self:tableName())
		if type(what) == "table" then
			for name, f in pairs(self:fields()) do
				local value = what[name]
				if value then
					select:where("?#="..self:fieldPlaceholder(f), name, value)
				end
			end
		else
			local pk = self:pk()
			select:where("?#="..self:fieldPlaceholder(pk), pk:name(), what)
		end
		local res = self:cacher() and ModelSqlSlot(self:cacher(), self, select)() or select()
		if not res then
			return nil
		end
		new:values(res)
		return new
	end;
	all = function (self, limitFrom, limitTo)
		local qs = require "luv.db.models".QuerySet(self)
		if limitFrom then
			qs:limit(limitFrom, limitTo)
		end
		local order = self:order()
		if order then
			qs:order("table" == type(order) and unpack(order) or order)
		end
		return qs
	end;
	-- Save, insert, update, create
	insert = function (self)
		if not self:valid() then
			Exception "validation error"
		end
		local insert = self:db():InsertRow():into(self:tableName())
		for name, f in pairs(self:fields()) do
			if not f:isA(references.ManyToMany) and not (f:isA(references.OneToOne) and f:backLink()) and not f:isA(references.OneToMany) then
				if f:isA(references.ManyToOne) or f:isA(references.OneToOne) then
					local val = f:value()
					if val then
						val = val:field(f:toField() or val:pkName()):value()
					end
					insert:set("?#="..self:fieldPlaceholder(f), name, val)
				else
					local val = f:value()
					if "nil" == type(val) then
						val = f:defaultValue()
					end
					if val then
						if f:isA(fields.Datetime) then
							val = os.date("%Y-%m-%d %H:%M:%S", val)
						elseif f:isA(fields.Date) then
							val = os.date("%Y-%m-%d", val)
						end
					end
					insert:set("?#="..self:fieldPlaceholder(f), name, val)
				end
			end
		end
		if not insert() then
			self:addError(self:db():error())
			return false
		end
		-- If Fields.Id than retrieve new generated ID
		local pk = self:pkField()
		if pk:isA(fields.Id) then
			pk:value(self:db():lastInsertId())
		end
		-- Save references
		for _, f in pairs(self:fields()) do
			if f:isA(references.ManyToMany) then
				f:insert()
			end
		end
		self:clearCacheTag()
		return true
	end;
	update = function (self)
		if not self:valid() then
			Exception("Validation error! "..require "luv.dev".dump(self:errors()))
		end
		local updateRow = self:db():UpdateRow(self:tableName())
		local pk = self:pkField()
		local pkName = pk:name()
		updateRow:where("?#="..self:fieldPlaceholder(pk), pkName, pk:value())
		for name, f in pairs(self:fields()) do
			if not f:isA(references.ManyToMany) and not (f:isA(references.OneToOne) and f:backLink()) and not f:isA(references.OneToMany) and not f:pk() then
				if f:isA(references.ManyToOne) or f:isA(references.OneToOne) then
					local val = f:value()
					if val then
						val = val:field(f:toField() or val:pkName()):value()
					end
					updateRow:set("?#="..self:fieldPlaceholder(f), name, val)
				else
					local val = f:value()
					if "nil" == type(val) then
						val = f:defaultValue()
					end
					if val then
						if f:isA(fields.Datetime) then
							val = os.date("%Y-%m-%d %H:%M:%S", val)
						elseif f:isA(fields.Date) then
							val = os.date("%Y-%m-%d", val)
						end
					end
					updateRow:set("?#="..self:fieldPlaceholder(f), name, val)
				end
			end
		end
		updateRow()
		for _, f in pairs(self:fields()) do
			if f:isA(references.ManyToMany) then
				f:update()
			end
		end
		self:clearCacheTag()
		return true
	end;
	save = function (self)
		local pk = self:pkField()
		local pkName = pk:name()
		if not pk:value() or not self:db():SelectCell(pkName):from(self:tableName()):where("?#="..self:fieldPlaceholder(pk), pkName, pk:value())() then
			return self:insert()
		else
			return self:update()
		end
	end;
	delete = function (self)
		local pk = self:pkField()
		local pkName = pk:name()
		self:clearCacheTag()
		return self:db():DeleteRow():from(self:tableName()):where("?#="..self:fieldPlaceholder(pk), pkName, pk:value())()
	end;
	create = function (self, ...)
		local obj = self(...)
		if not obj:insert() then
			return nil
		end
		self:clearCacheTag()
		return obj
	end;
	-- Create and drop
	htmlId = function (self)
		return self:tableName()
	end;
	tableName = function (self, ...)
		if select("#", ...) > 0 then
			self._tableName = (select(1, ...))
			return self
		else
			if (not self._tableName) then
				self._tableName = string.gsub(self:label(), " ", "_")
			end
			return self._tableName
		end
	end;
	constraintModels = function (self)
		local models = {}
		for _, f in pairs(self:fields()) do
			if f:isA(references.OneToMany) or (f:isA(references.OneToOne) and not f:backLink()) then
				table.insert(models, f:refModel())
			end
		end
		return models
	end,
	fieldTypeSql = function (self, field)
		if field:isA(fields.Text) then
			if field:maxLength() ~= 0 and field:maxLength() < 65535 then
				return "VARCHAR("..field:maxLength()..")"
			else
				return "TEXT"
			end
		elseif field:isA(fields.Boolean) then
			return "INT(1)"
		elseif field:isA(fields.Int) then
			return "INT(4)"
		elseif field:isA(fields.Datetime) then
			return "DATETIME"
		elseif field:isA(fields.Date) then
			return "DATE"
		elseif field:isA(fields.Time) then
			return "TIME"
		elseif field:isA(references.ManyToOne) or field:isA(references.OneToOne) then
			return self:fieldTypeSql(field:refModel():field(field:toField() or field:refModel():pkName()))
		else
			Exception"Unsupported field type!"
		end
	end;
	createTable = function (self)
		local c = self:db():CreateTable(self:tableName())
		-- Fields
		local hasPk = false
		for name, f in pairs(self:fields()) do
			if not f:isA(references.OneToMany) and not f:isA(references.ManyToMany) and not (f:isA(references.OneToOne) and f:backLink()) then
				hasPk = hasPk or f:pk()
				c:field(name, self:fieldTypeSql(f), {
					primaryKey = f:pk();
					unique = f:unique();
					null = not f:required(),
					serial = f:isA(fields.Id);
				})
				if f:isA(references.ManyToOne) or f:isA(references.OneToOne) then
					local onDelete
					if f:required() or f:pk() then
						onDelete = "CASCADE"
					else
						onDelete = "SET NULL"
					end
					c:constraint(name, f:tableName(), f:refModel():pkName(), "CASCADE", onDelete)
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
		for _, f in pairs(self:fields()) do
			if f:isA(references.ManyToMany) then
				f:createTable()
			end
		end
	end,
	dropTable = function (self)
		self:clearCacheTag()
		return self:db():DropTable(self:tableName())()
	end;
	dropTables = function (self)
		for _, f in pairs(self:fields()) do
			if f:isA(references.ManyToMany) then
				f:dropTable()
			end
		end
		return self:dropTable()
	end;
	-- Caching
	clearCacheTag = function (self)
		if self:cacher() then
			ModelTag(self:cacher(), self):clear()
		end
		return self
	end;
	-- Ajax
	ajaxHandler = function (self, data)
		if not data.field or not self:field(data.field) then
			return false
		end
		local F = require "luv.forms".Form:extend{
			id = self:pk():clone();
			field = fields.Text{required=true};
			value = self:field(data.field):clone();
			set = fields.Submit{defaultValue="Set"};
			initModel = function (self, model)
				model[self.field] = self.value
			end;
		}
		local f = F(data)
		if not f:submitted() then
			return false
		end
		if not f:valid() then
			return json.serialize{status="error";errors=f:errors()}
		end
		local obj = self:find(f.id)
		if not obj then
			return false
		end
		f:initModel(obj)
		if not obj:update() then
			return json.serialize{status="error";errors=f:errors()}
		end
		return json.serialize{status="ok"}
	end;
}

local Tree = Model:extend{
	__tag = .....".Tree";
	hasChildren = Model.abstractMethod;
	children = Model.abstractMethod;
	parentNode = Model.abstractMethod;
	removeChildren = Model.abstractMethod;
	addChild = Model.abstractMethod;
	addChildren = Model.abstractMethod;
	childrenCount = Model.abstractMethod;
	findRoot = Model.abstractMethod;
}

local NestedSet = Tree:extend{
	__tag = .....".NestedSet";
	hasChildren = function (self) return self.right-self.left > 1 end;
	children = function (self)
		return self._parent:all():filter{left__gt=self.left;right__lt=self.right;level=self.level+1}:value()
	end;
	parentNode = function (self)
		if 0 == self.level then
			return nil
		end
		-- TODO: rewrite to find{}
		return self._parent:all(1):filter{left__lt=self.left;right__gt=self.right;level=self.level-1}:value()[1]
	end;
	removeChildren = function (self)
		if not self:hasChildren() then
			return true
		end
		local db = self:db()
		db:beginTransaction()
		db:Delete():from(self:tableName())
			:where("?#>?d", "left", self.left)
			:andWhere("?#<?d", "right", self.right)()
		db:Update(self:tableName())
			:set("?#=?#-?d", "left", "left", self.right-self.left-1)
			:set("?#=?#-?d", "right", "right", self.right-self.left-1)
			:where("?#>?d", "left", self.right)()
		self.right = self.left+1
		if not self:update() then
			db:rollback()
			return false
		end
		db:commit()
		return true
	end;
	addChild = function (self, child)
		if not child:isA(self._parent) then Exception "not valid child class" end
		child.level = self.level+1
		child.left = self.left+1
		child.right = self.left+2
		local db = self:db()
		db:beginTransaction()
		db:Update(self:tableName())
			:set("?#=?#+2", "left", "left")
			:where("?#>?d", "left", self.left)()
		db:Update(self:tableName())
			:set("?#=?#+2", "right", "right")
			:where("?#>?d", "right", self.left)()
		if not child:insert() then
			db:rollback()
			return false
		end
		db:commit()
		return true
	end;
	childrenCount = function (self) return (self.right-self.left-1)/2 end;
	findRoot = function (self) return self:find{left=1} end;
	delete = function (self)
		local db = self:db()
		db:beginTransaction()
		db:Delete():from(self:tableName())
			:where("?#>?d", "left", self.left)
			:where("?#<?d", "right", self.right)()
		Tree.delete(self)
		db:Update(self:tableName())
			:set("?#=?#-?d", "left", "left", self.right-self.left+1)
			:where("?#>?d", "left", self.right)()
		db:Update(self:tableName())
			:set("?#=?#-?d", "right", "right", self.right-self.left+1)
			:where("?#>?d", "right", self.right)()
		db:commit()
	end;
}

local F = TreeNode:extend{
	__tag = .....".F";
	init = function (self, ...)
		TreeNode.init(self, ...)
		local mt = getmetatable(self)
		mt.__add = function (self, f2)
			return self._parent({self;f2}, "+")
		end;
		mt.__sub = function (self, f2)
			return self._parent({self;f2}, "-")
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
			if not self:connector() then
				return "?#"
			elseif "+" == self:connector() then
				return operandToString(self:children()[1]).."+"..operandToString(self:children()[2])
			elseif "-" == self:connector() then
				return operandToString(self:children()[1]).."-"..operandToString(self:children()[2])
			else
				Exception("unsupported operand "..self:connector())
			end
		end;
	end;
	values = function (self)
		local function operandValues (op)
			if "string" == type(op) or "number" == type(op) then
				return {op}
			else
				return op:values()
			end
		end
		local connector = self:connector()
		local children = self:children()
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
	negated = TreeNode.property;
	init = function (self, values)
		if not values then
			Exception "values expected"
		end
		TreeNode.init(self, {values}, "AND")
	end;
	__add = function (self, q)
		return self:clone():add(q, "AND")
	end;
	__sub = function (self, q)
		return self:clone():add(q, "OR")
	end;
	__unm = function (self)
		local obj = self:clone()
		obj:negated(not obj:negated())
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
		self._query = model:db():Select "*":from(self._model:tableName())
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
		if not condition then
			Exception "condition expected"
		end
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
		local obj = self:clone()
		obj._limits = {from=limitFrom;to=limitTo}
		return obj
	end;
	_processFieldName = function (self, s, parts)
		local curModel = self._model
		local result = {}
		for i, part in ipairs(parts) do
			if "pk" == part then
				part = curModel:pkName()
			end
			local field = curModel:field(part)
			if not curModel then
				Exception "invalid field"
			end
			if not field then
				Exception("field "..string.format("%q", part).." not founded")
			end
			if field:isA(references.Reference) then
				result = {field:refModel():tableName()}
				result.sql = "?#"
				if i == #parts then
					table.insert(result, field:refModel():pkName())
					result.sql = result.sql..".?#"
				end
				if field:isA(references.OneToOne) then
					if field:backLink() then
						s:join(
							field:refModel():tableName(),
							{
								"?#.?#=?#.?#";
								curModel:tableName();curModel:pkName();
								field:refModel():tableName();field:backRefFieldName()
							}
						)
					else
						s:join(
							field:refModel():tableName(),
							{
								"?#.?#=?#.?#";
								curModel:tableName();part;
								field:refModel():tableName();field:refModel():pkName()
							}
						)
					end
				elseif field:isA(references.OneToMany) then
					s:join(
						field:refModel():tableName(),
						{
							"?#.?#=?#.?#";
							curModel:tableName();curModel:pkName();
							field:refModel():tableName();field:relatedName()
						}
					)
				elseif field:isA(references.ManyToOne) then
					s:join(
						field:refModel():tableName(),
						{"?#.?#=?#.?#";curModel:tableName();part;field:refModel():tableName();field:refModel():pkName()}
					)
				elseif field:isA(references.ManyToMany) then
					s:join(
						field:tableName(),
						{
							"?#.?#=?#.?#";
							curModel:tableName();curModel:pkName();
							field:tableName();curModel:tableName()
						}
					)
					s:join(
						field:refModel():tableName(),
						{
							"?#.?#=?#.?#";
							field:tableName();field:refModel():tableName();
							field:refModel():tableName();field:refModel():pkName()
						}
					)
				end
				curModel = field:refModel()
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
				valStr = operators[op]..self._model:fieldPlaceholder(res.field or res[#res])
			end
			result.sql = (result.sql and (result.sql.." AND ") or "")..res.sql..valStr
			for _, val in ipairs(res) do
				table.insert(result, val)
			end
			if "isnull" ~= op then
				table.insert(result, "table" == type(v) and v.isA and v:isA(Model) and v.pk or v)
			end
		end
		return result
	end;
	_processQ = function (self, s, q)
		local result = {}
		local op = q:connector()
		for _, v in ipairs(q:children()) do
			local res = v.isA and v:isA(Q) and self:_processQ(s, v) or self:_processFilter(s, v)
			result.sql = (result.sql and (result.sql.." "..op.." ") or "")..res.sql
			for _, value in ipairs(res) do
				table.insert(result, value)
			end
		end
		result.sql = (q:negated() and "(NOT (" or "(")..result.sql..(q:negated() and "))" or ")")
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
	value = function (self)
		if not self._evaluated then
			self:_evaluate()
		end
		return self._values
	end;
	count = function (self)
		local s = self._model:db():SelectCell "COUNT(*)":from(self._model:tableName())
		self:_applyConditions(s)
		return tonumber(s())
	end;
	asSql = function (self)
		local s = self._query:clone()
		self:_applyConditions(s)
		return tostring(s)
	end;
	update = function (self, set)
		local s = self._model:db():Select(self._model:pkName()):from(self._model:tableName())
		self:_applyConditions(s)
		local u = self._model:db():Update(self._model:tableName()):where("?# IN (?a)", self._model:pkName(), table.imap(s(), f ("a["..string.format("%q", self._model:pkName()).."]")))
		local val
		for k, v in pairs(set) do
			if type(v) == "table" and v.isA and v:isA(Model) then
				val = v.pk
			else
				val = v
			end
			u:set("?#="..self._model:fieldPlaceholder(self._model:field(k)), k, val)
		end
		return u()
	end;
	delete = function (self)
		local s = self._model:db():Select(self._model:pkName()):from(self._model:tableName())
		self:_applyConditions(s)
		local u = self._model:db():Delete():from(self._model:tableName()):where("?# IN (?a)", self._model:pkName(), table.imap(s(), f ("a["..string.format("%q", self._model:pkName()).."]")))
		return u()
	end;
	__call = function (self, ...)
		if not self._evaluated then
			self:_evaluate()
		end
		return ipairs(self._values, ...)
	end;
	__index = function (self, field)
		local res = self._parent[field]
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
	model = Object.property;
	onPage = Object.property;
	init = function (self, model, onPage)
		self:model(model)
		self:onPage(onPage)
		self._query = model:all()
	end;
	total = function (self)
		if not self._total then
			self._total = self._query:count()
		end
		return self._total
	end;
	page = function (self, page)
		return self._query:limit((page-1)*self._onPage, page*self._onPage)
	end;
	pagesTotal = function (self) return math.ceil(self:total()/self:onPage()) end;
	order = function (self, ...) self._query = self._query:order(...) return self end;
	filter = function (self, ...) self._query = self._query:filter(...) return self end;
	exclude = function (self, ...) self._query = self._query:exclude(...) return self end;
}

-- Tables

local function tablesListForModels (models)
	local tables = {}
	table.imap(models, function (model)
		local tableName = model:tableName()
		for _, info in ipairs(tables) do
			if info[1] == tableName then
				return nil
			end
		end
		table.insert(tables, {model:tableName();model})
		table.imap(model:referenceFields(nil, references.ManyToMany), function (field)
			local tableName = field:tableName()
			for _, info in ipairs(tables) do
				if info[1] == tableName then
					return nil
				end
			end
			table.insert(tables, {field:tableName();field})
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
			if jObj:isA(Model) then
				local o2o = jObj:referenceField(iObj, references.OneToOne)
				if jObj:referenceField(iObj, references.ManyToOne)
				or (o2o and not jObj:field(o2o):backLink()) then
					tables[i], tables[j] = tables[j], tables[i]
					break
				end
			else
				if jObj:refModel():tableName() == iTbl
				or jObj:container():tableName() == iTbl then
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
	Model=Model;ModelSlot=ModelSlot;ModelTag=ModelTag;Tree=Tree;
	NestedSet=NestedSet;QuerySet=QuerySet;Paginator=Paginator;F=F;Q=Q;
	tablesListForModels=tablesListForModels;
	sortTablesList=sortTablesList;dropModels=dropModels;
	createModels=createModels;
}
