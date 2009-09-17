local table = require"luv.table"
local string = require"luv.string"
local os, debug, loadstring, assert, setfenv = os, debug, loadstring, assert, setfenv
local require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, tonumber = require, rawget, rawset, getmetatable, pairs, unpack, tostring, io, type, assert, tonumber
local math, ipairs, error, select = math, ipairs, error, select
local Object, Struct, fields, references, Exception = require"luv.oop".Object, require"luv".Struct, require"luv.fields", require"luv.fields.references", require"luv.exceptions".Exception
local cache = require "luv.cache.frontend"
local crypt = require "luv.crypt"
local TreeNode = require "luv.utils".TreeNode
local json = require "luv.utils.json"
local sql, keyvalue, Redis = require"luv.db.sql", require"luv.db.keyvalue", require"luv.db.keyvalue.redis".Driver
local checkTypes = require"luv.checktypes".checkTypes

module(...)

local MODULE = (...)
local serialize = string.serialize
local abstract = Object.abstractMethod
local property = Object.property

-- Tag of Model
local ModelTag = cache.Tag:extend{
	__tag = .....".ModelTag";
	init = function (self, backend, model)
		cache.Tag.init(self, backend, model:tableName())
	end;
}

-- Slot of Model record by condition
local ModelCondSlot = cache.Slot:extend{
	__tag = .....".ModelCondSlot";
	init = function (self, backend, model, condition)
		cache.Slot.init(self, backend, model:tableName().."_"..tostring(crypt.Md5(serialize(condition))):slice(1, 8))
		self:addTag(ModelTag(backend, model))
	end;
}

local Model = Struct:extend{
	__tag = .....".Model";
	__eq = function (self, second)
		local pkValue = self.pk
		if pkValue == nil then
			return false
		end
		return pkValue == second.pk
	end;
	__tostring = function (self) return tostring(self.pk) end;
	modelsList = {};
	cacher = property;
	ajaxUrl = property "string";
	db = property;
	tableName = property("string", function (self)
		if (not self._tableName) then
			self._tableName = self:label():gsub(" ", "_")
		end
		return self._tableName
	end, nil);
	label = property("string", "self.Meta.label or self.Meta.labels[1]", "self.Meta.label");
	labelMany = property("string",
		function (self) return self.Meta and (self.Meta.labelMany or self.Meta.labels[2]) or Exception"define Meta first" end,
		"self.Meta.labelMany"
	);
	order = property(nil, "self.Meta.order", "self.Meta.order");
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
		if not table.empty(new:fields()) then
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
			Exception"abstract model can't be created (extend it first)"
		end
		self:fields(table.map(classFields, "clone"))
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
		new:fields(table.map(self:fields(), "clone"))
		return new
	end;
	pkName = function (self)
		local pk = self:pkField()
		if not pk then
			return nil
		end
		return pk:name()
	end;
	pkField = function (self)
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
	-- Find
	fieldPlaceholder = function (self, field)
		if not field then
			Exception"field expected"
		end
		if not field.isA then
			field = self:field(field)
		end
		if not field or not field.isA or not field:isA(fields.Field) then
			Exception"field required"
		end
		if not field:required() then
			return "?n"
		end
		if field:isA(fields.Text) or field:isA(fields.Date) or field:isA(fields.Datetime) then
			return "?"
		elseif field:isA(fields.Int) then
			return "?d"
		elseif field:isA(references.ManyToOne) or field:isA(references.OneToOne) then
			return "?n"
		else
			Exception"Unsupported field type!"
		end
	end;
	-- Find and load one record that meets condition
	_loadOneByCond = function (self, condition)
		local db, tableName = self:db(), self:tableName()
		if db:isA(sql.Driver) then
			local select = db:SelectRow():from(tableName)
			if "table" == type(condition)  then
				for name, value in pairs(condition) do
					local f = self:field(name)
					if f then
						select:where("?#="..self:fieldPlaceholder(f), name, value)
					end
				end
			else
				local pk = self:pkField()
				select:where("?#="..self:fieldPlaceholder(pk), pk:name(), condition)
			end
			return select()
		elseif db:isA(Redis) then
			local resPk
			if "table" == type(condition) then
				local pks = db:smembers(tableName, 0, -1)
				for _, pk in ipairs(pks) do
					resPk = pk
					for f, v in pairs(condition) do
						if v ~= db:get(tableName..":"..pk..":"..f) then
							resPk = nil
							break
						end
					end
				end
			else
				resPk = condition
			end
			if resPk then
				local keys = db:keys(tableName..":"..resPk..":*")
				if not table.empty(keys) then
					local vals = db:get(keys)
					local values = {}
					for k, v in pairs(vals) do
						values[k:slice(k:findLast":"+1)] = v
					end
					return values
				end
			end
		else
			Exception"unsupported driver"
		end
	end;
	find = function (self, condition)
		local cacher, cacheSlot, values = self:cacher()
		if cacher then
			cacheSlot = ModelCondSlot(cacher, self, condition)
		end
		values = cacheSlot and cacheSlot:thru(self):_loadOneByCond(condition) or self:_loadOneByCond(condition)
		if not values then
			return nil
		end
		return self(values)
	end;
	all = function (self, limitFrom, limitTo)
		local db, qs = self:db()
		if db:isA(sql.Driver) then
			qs = require "luv.db.models".SqlQuerySet(self)
		elseif db:isA(keyvalue.Driver) then
			qs = require "luv.db.models".KeyValueQuerySet(self)
		else
			Exception"unsupported driver"
		end
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
			Exception("validation fail: "..require"luv.dev".dump(self:errors()))
		end
		local db = self:db()
		local tableName = self:tableName()
		if db:isA(sql.Driver) then
			local insert = db:InsertRow():into(tableName)
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
							elseif f:isA(fields.Time) then
								val = tostring(math.floor(val/60/60))..":"..tostring(math.floor(val/60)%60)..":"..tostring(val%60)
							end
						end
						insert:set("?#="..self:fieldPlaceholder(f), name, val)
					end
				end
			end
			if not insert() then
				self:addError(db:error())
				return false
			end
			-- If Fields.Id than retrieve new generated ID
			local pk = self:pkField()
			if pk:isA(fields.Id) then
				pk:value(db:lastInsertId())
			end
			-- Save references
			for _, f in pairs(self:fields()) do
				if f:isA(references.ManyToMany) then
					f:insert()
				end
			end
		elseif db:isA(Redis) then
			if self:pkField():isA(fields.Id) then
				self.pk = db:incr(tableName..":lastInsertId")
			end
			local pk = self.pk
			-- For references as primary keys
			while "table" == type(pk) do
				pk = pk.pk
			end
			db:sadd(tableName, pk)
			for name, f in pairs(self:fields()) do
				local value = f:value()
				if nil == value then
					value = f:defaultValue()
				end
				if value then
					if f:isA(references.OneToOne) then
						db:set(f:refModel():tableName()..":"..value.pk..":"..f:backRefFieldName(), pk)
						db:set(tableName..":"..pk..":"..name, value.pk)
					elseif f:isA(references.OneToMany) then
						local dbKey = tableName..":"..pk..":"..name
						for _, v in ipairs(value) do
							db:sadd(dbKey, v.pk)
							db:set(f:refModel():tableName()..":"..v.pk..":"..f:relatedName(), pk)
						end
					elseif f:isA(references.ManyToOne) then
						db:set(tableName..":"..pk..":"..name, value.pk)
						db:sadd(f:refModel():tableName()..":"..value.pk..":"..f:relatedName(), pk)
					elseif f:isA(references.ManyToMany) then
						local dbKey = tableName..":"..pk..":"..name
						for _, v in ipairs(value) do
							db:sadd(dbKey, v)
							db:sadd(f:refModel():tableName()..":"..v.pk..":"..f:relatedName(), pk)
						end
					else
						db:set(tableName..":"..pk..":"..name, value)
					end
				end
			end
		else
			Exception"unsupported driver"
		end
		self:clearCacheTag()
		return true
	end;
	update = function (self)
		if not self:valid() then
			Exception("validation fail "..require "luv.dev".dump(self:errors()))
		end
		local db = self:db()
		local tableName = self:tableName()
		if db:isA(sql.Driver) then
			local updateRow = db:UpdateRow(tableName)
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
						if nil == val then
							val = f:defaultValue()
						end
						if val then
							if f:isA(fields.Datetime) then
								val = os.date("%Y-%m-%d %H:%M:%S", val)
							elseif f:isA(fields.Date) then
								val = os.date("%Y-%m-%d", val)
							elseif f:isA(fields.Time) then
								val = tostring(math.floor(val/60/60))..":"..tostring(math.floor(val/60)%60)..":"..tostring(val%60)
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
		elseif db:isA(Redis) then
			local pk = self.pk
			for name, f in pairs(self:fields()) do
				db:set(tableName..":"..pk..":"..name, nil)
				local value = f:value()
				if value then
					if f:isA(references.OneToOne) then
						db:set(f:refModel():tableName()..":"..value.pk..":"..f:relatedName(), pk)
						db:set(tableName..":"..pk..":"..name, value.pk)
					elseif f:isA(references.OneToMany) then
						db:set(f:refModel():tableName()..":"..value.pk..":"..f:relatedName(), pk)
						local dbKey = tableName..":"..pk..":"..name
						for _, v in ipairs(value) do
							db:sadd(dbKey, v)
						end
					elseif f:isA(references.ManyToOne) then
						db:set(tableName..":"..pk..":"..name, value.pk)
						local dbKey = f:refModel():tableName()..":"..value.pk..":"..f:relatedName()
						db:sadd(dbKey, pk)
					elseif f:isA(references.ManyToMany) then
						local dbKey = f:refModel():tableName()..":"..value.pk..":"..f:relatedName()
						db:sadd(dbKey, pk)
						dbKey = tableName..":"..pk..":"..name
						for _, v in ipairs(value) do
							db:sadd(dbKey, v)
						end
					else
						db:set(tableName..":"..pk..":"..name, value)
					end
				end
			end
		else
			Exception"unsupported driver"
		end
		self:clearCacheTag()
		return true
	end;
	save = function (self)
		local db = self:db()
		local tableName = self:tableName()
		local pk = self:pkField()
		local pkName = pk:name()
		if db:isA(sql.Driver) then
			if not pk:value() or not db:SelectCell(pkName):from(tableName):where("?#="..self:fieldPlaceholder(pk), pkName, pk:value())() then
				return self:insert()
			else
				return self:update()
			end
		elseif db:isA(keyvalue.Driver) then
			if not pk:value() or not db:get(tableName..":"..pk:value()..":"..pkName) then
				return self:insert()
			else
				return self:update()
			end
		else
			Exception"unsupported driver"
		end
	end;
	delete = function (self)
		local db = self:db()
		local tableName = self:tableName()
		local pkF = self:pkField()
		local pkName = pkF:name()
		local pk = pkF:value()
		while "table" == type(pk) do
			pk = pk.pk
		end
		self:clearCacheTag()
		if db:isA(sql.Driver) then
			return db:DeleteRow():from(tableName):where("?#="..self:fieldPlaceholder(pkF), pkName, pk)()
		elseif db:isA(Redis) then
			db:srem(tableName, pk)
			local keys = db:keys(tableName..":"..pk..":*")
			if not table.empty(keys) then
				db:del(keys)
			end
		else
			Exception"unsupported driver"
		end
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
		return self:tableName()..self.pk
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
			return "BOOLEAN"
		elseif field:isA(fields.Int) then
			return "INTEGER"
		elseif field:isA(fields.Datetime) then
			return "DATETIME"
		elseif field:isA(fields.Float) then
			return "FLOAT"
		elseif field:isA(fields.Date) then
			return "DATE"
		elseif field:isA(fields.Time) then
			return "TIME"
		elseif field:isA(references.ManyToOne) or field:isA(references.OneToOne) then
			return self:fieldTypeSql(field:refModel():field(field:toField() or field:refModel():pkName()))
		else
			Exception"unsupported field type"
		end
	end;
	createTable = function (self)
		local db = self:db()
		if db:isA(sql.Driver) then
			local c = db:CreateTable(self:tableName())
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
		elseif db:isA(Redis) then
			-- nothing to do?
		else
			Exception"unsupported driver"
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
		local db = self:db()
		local tableName = self:tableName()
		self:clearCacheTag()
		if db:isA(sql.Driver) then
			return db:DropTable(tableName)()
		elseif db:isA(Redis) then
			db:del(tableName)
			local keys = db:keys(tableName..":*")
			if not table.empty(keys) then
				db:del(keys)
			end
		else
			Exception"unsupported driver"
		end
		return self
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
		if self:cacher() then ModelTag(self:cacher(), self):clear() end
		return self
	end;
}

local Tree = Model:extend{
	__tag = .....".Tree";
	hasChildren = abstract;
	children = abstract;
	parentNode = abstract;
	removeChildren = abstract;
	addChild = abstract;
	addChildren = abstract;
	childrenCount = abstract;
	findRoot = abstract;
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
		if not child:isA(self._parent) then Exception"not valid child class" end
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
	negated = property"boolean";
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
	add = function (self, child, connector)
		if table.size(self:children()) < 2 then
			 self:connector(connector)
		end
		if connector == self:connector() and not self:negated() then
			table.insert(self:children(), child)
		else
			local obj = self
			self = self:parent()(obj)
			table.insert(self:children(), child)
			self:connector(connector)
		end
		return self
	end;
}

local QuerySet = Object:extend{
	__tag = .....".QuerySet";
	model = property(Model);
	_evaluated = false;
	evaluated = property"boolean";
	orders = property"table";
	limits = property"table";
	values = property"table";
	q = property(Q);
}

local SqlQuerySet = QuerySet:extend{
	__tag = .....".SqlQuerySet";
	query = property;
	init = function (self, model)
		self:model(model)
		self:orders{}
		self:limits{}
		self:values{}
		self:query(model:db():Select"*":from(model:tableName()))
	end;
	clone = function (self)
		local obj = Object.clone(self)
		obj:orders(table.copy(obj:orders()))
		obj:limits(table.copy(obj:limits()))
		obj:values(table.copy(obj:values()))
		obj:query(obj:query():clone())
		return obj
	end;
	filter = function (self, condition)
		if not condition then
			Exception"condition expected"
		end
		local obj = self:clone()
		obj:evaluated(false)
		obj:values{}
		obj:q(obj:q() and (obj:q() + Q(condition)) or Q(condition))
		return obj
	end;
	exclude = function (self, condition)
		local obj = self:clone()
		obj:evaluated(false)
		obj:values{}
		obj:q(obj:q() and (obj:q() + -Q(condition)) or -Q(condition))
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
		obj:limits{from=limitFrom;to=limitTo}
		return obj
	end;
	_processFieldName = function (self, s, parts)
		local curModel = self._model
		local result = {}
		local field
		for i, part in ipairs(parts) do
			if "pk" == part then
				part = curModel:pkName()
			end
			field = curModel:field(part)
			if not curModel then
				Exception"invalid field"
			end
			if not field then
				Exception("field "..("%q"):format(part).." not founded")
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
			if k:find"__" then
				parts = k:explode"__"
			else
				parts = {k}
			end
			local op = parts[#parts]
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
				valStr = operators[op]..self:model():fieldPlaceholder(res.field or res[#res])
			end
			local f = res.field or self:model():field(res[#res])
			if f:isA(fields.Datetime) then
				v = os.date("%Y-%m-%d %H:%M:%S", v)
			elseif f:isA(fields.Date) then
				v = os.date("%Y-%m-%d", v)
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
			s:where(res.sql:slice(2, -2), unpack(values))
		end
		if self._limits.from then
			s:limit(self._limits.from, self._limits.to)
		end
		if not table.empty(self._orders) then
			s:order(unpack(self._orders))
		end
	end;
	_evaluate = function (self)
		self:evaluated(true)
		self:_applyConditions(self:query())
		self:values{}
		for _, v in ipairs(self:query()() or {}) do
			table.insert(self:values(), self:model()(v))
		end
	end;
	value = function (self)
		if not self:evaluated() then
			self:_evaluate()
		end
		return self:values()
	end;
	count = function (self)
		local model = self:model()
		local s = model:db():SelectCell"COUNT(*)":from(model:tableName())
		self:_applyConditions(s)
		return tonumber(s())
	end;
	asSql = function (self)
		local s = self:query():clone()
		self:_applyConditions(s)
		return tostring(s)
	end;
	update = function (self, set)
		local model = self:model()
		local db = model:db()
		local s = db:Select(model:pkName()):from(model:tableName())
		self:_applyConditions(s)
		local pkName = model:pkName()
		local u = db:Update(model:tableName()):where("?# IN (?a)", model:pkName(), table.imap(s(), function (a) return a[pkName] end))
		local val
		for k, v in pairs(set) do
			if type(v) == "table" and v.isA and v:isA(Model) then
				val = v.pk
			else
				val = v
			end
			u:set("?#="..model:fieldPlaceholder(model:field(k)), k, val)
		end
		return u()
	end;
	delete = function (self)
		local model = self:model()
		local db = model:db()
		local s = db:Select(model:pkName()):from(model:tableName())
		self:_applyConditions(s)
		local pkName = model:pkName()
		local u = db:Delete():from(model:tableName()):where("?# IN (?a)", model:pkName(), table.imap(s(), function (a) return a[pkName] end))
		return u()
	end;
	__call = function (self, ...)
		if not self:evaluated() then
			self:_evaluate()
		end
		return ipairs(self:values(), ...)
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

local KeyValueQuerySet = QuerySet:extend{
	__tag = .....".KeyValueQuerySet";
	init = function (self, model)
		self:model(model)
		self:orders{}
		self:limits{}
		self:values{}
	end;
	clone = function (self)
		local obj = Object.clone(self)
		obj:orders(table.copy(obj:orders()))
		obj:limits(table.copy(obj:limits()))
		obj:values(table.copy(obj:values()))
		return obj
	end;
	filter = function (self, condition)
		if not condition then
			Exception"condition expected"
		end
		local obj = self:clone()
		obj:evaluated(false)
		obj:values{}
		obj:q(obj:q() and (obj:q() + Q(condition)) or Q(condition))
		return obj
	end;
	exclude = function (self, condition)
		local obj = self:clone()
		obj:evaluated(false)
		obj:values{}
		obj:q(obj:q() and (obj:q() + -Q(condition)) or -Q(condition))
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
		obj:limits{from=limitFrom;to=limitTo}
		return obj
	end;
	_fieldName = function (self, parts)
		local curModel = self:model()
		local db = curModel:db()
		local result = ""
		for i, part in ipairs(parts) do
			if "pk" == part then
				part = curModel:pkName()
			end
			if not curModel then
				Exception"invalid field"
			end
			local field = curModel:field(part)
			if not field then
				Exception("field "..("%q"):format(part).." not founded")
			end
			if field:isA(references.Reference) then
				if field:isA(references.ManyToOne) or field:isA(references.OneToOne) then
					result = result..' res = db:get("'..curModel:tableName()..':"..res..":'..part..'")'
				else
					if db:isA(Redis) then -- Redis has native arrays
						result = result..' res = db:smembers("'..curModel:tableName()..':"..res..":'..part..'")'
					else
						result = result..' res = db:get("'..curModel:tableName()..':"..res..":'..part..'")'
					end
				end
				curModel = field:refModel()
			else
				result = result..' res = db:get("'..curModel:tableName()..':"..res..":'..part..'")'
				curModel = nil
			end
		end
		return result
	end;
	-- Creates validation function for given filter
	_valFuncTextForFilter = function (self, filter)
		local operators = {
			eq="==";exact="==";lt="<";gt=">";lte="<=";gte=">=";
			["in"]=true;isnull=true;beginswith=true;endswith=true;
			contains=true;
		}
		local result = "function (self, res) local db = self:model():db() "
		if "string" == type(filter) then
			filter = {pk=filter}
		end
		local retValue
		for k, v in pairs(filter) do
			local parts
			if k:find"__" then
				parts = k:explode"__"
			else
				parts = {k}
			end
			local op = parts[#parts]
			if operators[op] then
				table.remove(parts)
			else
				op = "eq"
			end
			result = result..self:_fieldName(parts)
			if "isnull" == op then
				retValue = v and "nil==res" or "nil~=res"
			elseif "in" == op then
				retValue = "table.ifind("..serialize(v)..", res)"
			elseif "beginswith" == op then
				retValue = "res:beginsWith"..("%q"):format(v)
			elseif "endswith" == op then
				retValue = "res:endsWith"..("%q"):format(v)
			elseif "contains" == op then
				retValue = "nil ~= res:find"..("%q"):format(v)
			else
				retValue = "res"..operators[op]..serialize("table" == type(v) and v.isA and v:isA(Model) and v.pk or v)
			end
		end
		return result.." return "..retValue.." end"
	end;
	-- Creates validation function for given Q
	_valFuncTextForQ = function (self, q)
		local result = "function (self, pk) return"
		if q:negated() then result = result.." not (" end
		local op = q:connector():lower()
		local first = true
		for _, v in ipairs(q:children()) do
			if first then first = false else result = result.." "..op end
			result = result.." ("..(v.isA and v:isA(Q) and self:_valFuncTextForQ(v) or self:_valFuncTextForFilter(v))..")(self, pk)"
		end
		if q:negated() then result = result..")" end
		return result.." end"
	end;
	-- Creates sort function text
	_sortFuncText = function (self, pks)
		local model = self:model()
		local tableName = model:tableName()
		local result = "function (pk1, pk2) local cache, db = cachedValues, db local val1, val2 if not cache[pk1] then cache[pk1] = {} end if not cache[pk2] then cache[pk2] = {} end"
		for _, v in ipairs(self._orders) do
			local f = "-" == string.slice(v, 1, 1) and v:slice(2) or v
			result = result.." if not cache[pk1]["..("%q"):format(f).."] then cache[pk1]["..("%q"):format(f)..'] = {db:get("'..model:tableName()..':"..pk1..":'..f..'")} end val1 = cache[pk1]['..("%q"):format(f).."][1]"
			result = result.." if not cache[pk2]["..("%q"):format(f).."] then cache[pk2]["..("%q"):format(f)..'] = {db:get("'..model:tableName()..':"..pk2..":'..f..'")} end val2 = cache[pk2]['..("%q"):format(f).."][1]"
			result = result.." if not val1 or not val2 then return false end"
			if "-" == v:slice(1, 1) then
				result = result.." if val1 > val2 then return true elseif val2 < val1 then return false end"
			else
				result = result.." if val1 < val2 then return true elseif val2 > val1 then return false end"
			end
		end
		return result.." end"
	end;
	-- Preloads values for sort (speed improvement)
	_cacheValuesForSorting = function (self, pks)
		local model = self:model()
		local tableName = model:tableName()
		local result = {}
		local dbKeys = {}
		for _, v in ipairs(self._orders) do
			for _, pk in ipairs(pks) do
				table.insert(dbKeys, tableName..":"..pk..":"..("-" == v:slice(1, 1) and v:slice(2) or v))
			end
		end
		local values = model:db():get(dbKeys)
		local typeFunc
		if "number" == type(pks[1]) then typeFunc = tonumber end
		for k, v in pairs(values) do
			local t, p, f = k:split(":", ":")
			if typeFunc then p = typeFunc(p) end
			result[p] = result[p] or {}
			result[p][f] = {v}
		end
		return result
	end;
	_sortPks = function (self, pks, sort)
		table.sort(pks, sort)
	end;
	_evaluate = function (self)
		local model, values = self:model(), {}
		self:evaluated(true)
		-- Filter
		local pks = self:q() and self:_validateAll(assert(loadstring("return ("..self:_valFuncTextForQ(self:q())..")"))()) or model:db():smembers(model:tableName())
		-- Sort
		if not table.empty(self._orders) then
			local sortFunc = assert(loadstring("return "..self:_sortFuncText(pks)))()
			setfenv(sortFunc, {cachedValues=self:_cacheValuesForSorting(pks);db=self:model():db()})
			self:_sortPks(pks, sortFunc)
		end
		-- Limit
		if self:limits().from then
			local limitedPks = {}
			for i = self:limits().from+1, math.min(#pks, self:limits().to) do
				table.insert(limitedPks, pks[i])
			end
			pks = limitedPks
		end
		-- Retrieve
		for _, pk in ipairs(pks or {}) do
			table.insert(values, model:find(pk))
		end
		self:values(values)
	end;
	value = function (self)
		if not self:evaluated() then
			self:_evaluate()
		end
		return self._values
	end;
	_validateAll = function (self, validator)
		local model = self:model()
		local pks = model:db():smembers(model:tableName())
		local result = {}
		for _, pk in ipairs(pks) do
			if validator(self, pk) then
				table.insert(result, pk)
			end
		end
		return result
	end;
	count = function (self)
		local model = self:model()
		return self:q() and #self:_validateAll(assert(loadstring("return ("..self:_valFuncTextForQ(self:q())..")"))()) or model:db():scard(model:tableName())
	end;
	update = function (self, set)
		local model, values = self:model(), {}
		-- Filter
		local pks = self:q() and self:_validateAll(assert(loadstring("return ("..self:_valFuncTextForQ(self:q())..")"))()) or model:db():smembers(model:tableName())
		-- Sort
		if not table.empty(self._orders) then
			local sortFunc = assert(loadstring("return "..self:_sortFuncText(pks)))()
			setfenv(sortFunc, {cachedValues=self:_cacheValuesForSorting(pks);db=self:model():db()})
			self:_sortPks(pks, sortFunc)
		end
		-- Limit
		if self:limits().from then
			local limitedPks = {}
			for i = self:limits().from+1, math.min(#pks, self:limits().to) do
				table.insert(limitedPks, pks[i])
			end
			pks = limitedPks
		end
		-- Update
		--[[TODOfor _, pk in ipairs(pks) then
			for
		end]]
	end;
	delete = function (self)
		local model, values = self:model(), {}
		-- Filter
		local pks = self:q() and self:_validateAll(assert(loadstring("return ("..self:_valFuncTextForQ(self:q())..")"))()) or model:db():smembers(model:tableName())
		-- Sort
		if not table.empty(self._orders) then
			local sortFunc = assert(loadstring("return "..self:_sortFuncText(pks)))()
			setfenv(sortFunc, {cachedValues=self:_cacheValuesForSorting(pks);db=self:model():db()})
			self:_sortPks(pks, sortFunc)
		end
		-- Limit
		if self:limits().from then
			local limitedPks = {}
			for i = self:limits().from+1, math.min(#pks, self:limits().to) do
				table.insert(limitedPks, pks[i])
			end
			pks = limitedPks
		end
		-- Delete
		local delKeys = {}
		for _, pk in ipairs(pks) do
			model:db():srem(model:tableName(), pk)
			local keys = model:db():keys(model:tableName()..":"..pk..":*")
			for _, key in ipairs(keys) do
				table.insert(delKeys, key)
			end
		end
		model:db():del(delKeys)
		return self
	end;
	__call = function (self, ...)
		if not self._evaluated then
			self:_evaluate()
		end
		return ipairs(self:values(), ...)
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
	model = property(Model);
	onPage = property"number";
	query = property;
	init = function (self, model, onPage)
		self:model(model)
		self:onPage(onPage)
		self:query(model:all())
	end;
	total = function (self)
		if not self._total then
			self._total = self:query():count()
		end
		return self._total
	end;
	page = function (self, page)
		return self:query():limit((page-1)*self._onPage, page*self._onPage)
	end;
	pagesTotal = function (self) return math.ceil(self:total()/self:onPage()) end;
	order = function (self, ...) self:query(self:query():order(...)) return self end;
	filter = function (self, ...) self:query(self:query():filter(...)) return self end;
	exclude = function (self, ...) self:query(self:query():exclude(...)) return self end;
}

-- Tables

local function tablesListForModels (models)
	local tables = {}
	table.map(models, function (model)
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
	Model=Model;ModelCondSlot=ModelCondSlot;ModelTag=ModelTag;Tree=Tree;
	NestedSet=NestedSet;QuerySet=QuerySet;SqlQuerySet=SqlQuerySet;
	KeyValueQuerySet=KeyValueQuerySet;Paginator=Paginator;F=F;Q=Q;
	tablesListForModels=tablesListForModels;
	sortTablesList=sortTablesList;dropModels=dropModels;
	createModels=createModels;
}
