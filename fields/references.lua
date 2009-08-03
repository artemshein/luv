local debug = debug
local string = require "luv.string"
local f = require "luv.function".f
local type, require, pairs, table, select, io, ipairs = type, require, pairs, table, select, io, ipairs
local fields, Exception = require "luv.fields", require "luv.exceptions".Exception
local widgets = require "luv.fields.widgets"
local sql, keyvalue, Redis = require"luv.db.sql", require"luv.db.keyvalue", require"luv.db.keyvalue.redis".Driver

module(...)

local MODULE = (...)
local property = fields.Field.property;

local Reference = fields.Field:extend{
	__tag = .....".Reference";
	relatedName = property;
	toField = property;
	refModel = property;
	role = property;
	init = function (self, params)
		if self._parent._parent == fields.Field then
			Exception"Instantiate of abstract class is not allowed!"
		end
		local Model = require "luv.db.models".Model
		if ("table" == type(params) and params.isA and params:isA(Model)) or "string" == type(params) then
			params = {references = params}
		end
		fields.Field.init(self, params)
	end;
	params = function (self, params)
		if "table" == type(params)  then
			self.toField = params.toField
			if "table" ~= type(params.references) then Exception "References must be a Model!" end
			self:refModel(params.references)
			self:relatedName(params.relatedName)
			fields.Field.params(self, params)
		else
			self:refModel(params or Exception "References required!")
		end
	end;
}

local ManyToMany = Reference:extend{
	__tag = .....".ManyToMany",
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
	end;
	valid = function (self)
		if self:required() and #self:value() == 0 then
			return false
		end
		return Reference.valid(self)
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if "table" ~= type(value) then
				value = nil
			else
				value = table.copy(value)
				if #value > 0 and "table" ~= type(value[1]) then
					value = self:refModel():all():filter{pk__in=value}:value()
				end
			end
			self._value = value
			return self
		else
			--[[if not self._value and self:container().pk then
				self:value(self:all():value())
			end]]
			return Reference.value(self)
		end
	end;
	tableName = function (self)
		if not self._tableName then
			local t1, t2 = string.replace(self:container():labelMany(), " ", "_"), string.replace(self:refModel():labelMany(), " ", "_")
			if t1 < t2 then
				self._tableName = t1.."2"..t2
			else
				self._tableName = t2.."2"..t1
			end
			local role = self:role()
			if role then
				self._tableName = self._tableName.."_"..role
			end
		end
		return self._tableName
	end;
	createBackLink = function (self)
		return require(MODULE).ManyToMany{references=self:container();relatedName=self:name();label=self:container():labelMany()}
	end;
	createTable = function (self)
		local container = self:container()
		local db = container:db()
		if db:isA(sql.Driver) then
			local refModel = self:refModel()
			local c = container:db():CreateTable(self:tableName())
			local containerTableName = container:tableName()
			local containerPkName = container:pkName()
			local refTableName = refModel:tableName()
			local refPkName = refModel:pkName()
			c:field(containerTableName, container:fieldTypeSql(container:field(containerPkName)), {required=true;null=false})
			c:constraint(containerTableName, containerTableName, containerPkName)
			c:field(refTableName, refModel:fieldTypeSql(refModel:field(refPkName)), {required=true;null=false})
			c:constraint(refTableName, refTableName, refPkName)
			c:uniqueTogether(containerTableName, refTableName)
			return c()
		elseif db:isA(Redis) then
			return
		else
			Exception"unsupported driver"
		end
	end;
	dropTable = function (self)
		local db = self:container():db()
		local tableName = self:tableName()
		if db:isA(sql.Driver) then
			return db:DropTable(tableName)()
		elseif db:isA(Redis) then
			return
		else
			Exception"unsupported driver"
		end
	end;
	insert = function (self)
		if self._value then
			local container, refModel = self:container(), self:refModel()
			if not container.pk then
				Exception"Primary key value must be set first!"
			end
			if not table.empty(self._value) then
				local s = container:db():Insert(container:fieldPlaceholder(container:pkField())..", "..refModel:fieldPlaceholder(refModel:pkField()), container:tableName(), refModel:tableName()):into(self:tableName())
				for _, v in pairs(self._value) do
					s:values(container.pk, v.pk)
				end
				s()
			end
			self._value = nil
		end
	end;
	add = function (self, values)
		local container, refModel = self:container(), self:refModel()
		if not container.pk then
			Exception "primary key value must be set first"
		end
		if "table" ~= type(values) or values.isA then
			values = {values}
		end
		local s = container:db():Insert(container:fieldPlaceholder(container:pkField())..", "..refModel:fieldPlaceholder(refModel:pkField()), container:tableName(), refModel:tableName()):into(self:tableName())
		for _, v in ipairs(values) do
			s:values(container.pk, 'table' == type(v) and v.pk or tostring(v))
		end
		s()
		self._value = nil
	end;
	update = function (self)
		if self._value then
			local container, refModel = self:container(), self:refModel()
			if not container.pk then
				Exception"Primary key value must be set first!"
			end
			container:db():Delete():from(self:tableName()):where("?#="..container:fieldPlaceholder(container:pkField()), container:tableName(), container.pk)()
			if "table" == type(self._value) and not table.empty(self._value) then
				local s = container:db():Insert(container:fieldPlaceholder(container:pkField())..", "..refModel:fieldPlaceholder(refModel:pkField()), container:tableName(), refModel:tableName()):into(self:tableName())
				for _, v in pairs(self._value) do
					s:values(container.pk, v.pk)
				end
				s()
			end
			self._value = nil
		end
	end;
	remove = function (self, values)
		local container, refModel = self:container(), self:refModel()
		container:db():Delete():from(self:tableName())
			:where("?#="..container:fieldPlaceholder(container:pkField()), container:tableName(), container.pk)
			:where("?# IN (?a)", refModel:tableName(), values)()
		self._value = nil
	end;
	all = function (self)
		local container, refModel = self:container(), self:refModel()
		if not container.pk then
			return nil
		end
		local models = require "luv.db.models"
		return refModel:all():filter{[self:relatedName().."__pk"]=container.pk}
	end;
	count = function (self)
		return self:all():count()
	end;
	empty = function (self)
		return 0 == self:count()
	end;
	relatedName = function (self, ...)
		if select("#", ...) > 0 then
			return Reference.relatedName(self, ...)
		else
			if not self._relatedName then
				self._relatedName = self:container():labelMany()
			end
			return Reference.relatedName(self)
		end
	end;
}

local ManyToOne = Reference:extend{
	__tag = .....".ManyToOne",
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			local value = (select(1, ...))
			if type(value) == "table" and not value:isA(self:refModel()) then
				Exception("Instance of "..self.ref.." or nil required!")
			elseif value ~= nil and value ~= "" and type(value) ~= "table" and not self:refModel():pkField():valid(value) then
				debug.dprint(self)
				debug.dprint(value)
				Exception"Invalid field value!"
			end
			return Reference.value(self, value)
		else
			local valType = type(self._value)
			if self._value and valType ~= "table" then
				self:value(self:refModel():find(self._value))
			end
			return Reference.value(self)
		end
	end;
	tableName = function (self)
		return self:refModel():tableName()
	end;
	createBackLink = function (self)
		return require(MODULE).OneToMany{references=self:container();relatedName=self:name();label=self:container():labelMany()}
	end;
	relatedName = function (self, ...)
		if select("#", ...) > 0 then
			return Reference.relatedName(self, ...)
		else
			if not self._relatedName then
				self._relatedName = string.replace(self:container():labelMany(), ' ', '_')
			end
			return Reference.relatedName(self)
		end
	end;
}

local getKeysForObjects = function (self, ...)
	local objKeys, params = {}, {select(1, ...)}
	for i = 1, select("#", ...) do
		local obj = params[i]
		if type(obj) ~= "table" or not obj.isA or not obj:isA(self:refModel()) then
			Exception("Instance of "..self:ref().." required!")
		end
		table.insert(objKeys, obj.pk)
	end
	return objKeys
end

local OneToMany = Reference:extend{
	__tag = .....".OneToMany";
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
	end;
	tableName = function (self)
		return self:refModel():tableName()
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			return Reference.value(self, ...)
		else
			return self
		end
	end;
	all = function (self)
		local container, refModel = self:container(), self:refModel()
		local refFieldName = refModel:referenceField(container, require(MODULE).ManyToOne)
		return refModel:all():filter{[refFieldName.."__pk"]=container.pk}
	end;
	filter = function (self, ...)
		return self:all():filter(...)
	end;
	exclude = function (self, ...)
		return self:all():exclude(...)
	end;
	count = function (self)
		return self:all():count()
	end;
	delete = function (self)
		return self:all():delete()
	end;
	update = function (self, ...)
		return self:all():update(...)
	end;
	add = function (self, ...)
		local refModel, model = self:refModel(), self:container()
		local toFieldName = refModel:referenceField(model, require(MODULE).ManyToOne)
		if not toFieldName then
			Exception"Backwards reference field not founded!"
		end
		local toFieldRelationFieldName = refModel:field(toFieldName):toField() or model:pkName()
		local toFieldRelationField = model:field(toFieldRelationFieldName)
		if not toFieldRelationField:value() then
			Exception"Relation field value must be set!"
		end
		local container = self:container()
		local update, i = container:db():Update(self:refModel():tableName())
		update:set("?#="..container:fieldPlaceholder(refModel:field(toFieldName)), toFieldName, toFieldRelationField:value())
		local refPkName = self:refModel():pkName()
		update:where("?# IN (?a)", refPkName, getKeysForObjects(self, ...))()
	end;
	remove = function (self)
		local container, refModel = self:container(), self:refModel()
		local toFieldName = refModel:referenceField(require(MODULE).ManyToOne, container)
		if refModel:field(toFieldName):required() then
			Exception"Can't remove references with required property(you should delete it or set another value instead)!"
		end
		return self:all():update{[toFieldName] = nil}
	end;
	createBackLink = function (self)
		return require(MODULE).ManyToOne{references=self:container();relatedName=self:name();label=self:container():label()}
	end;
	relatedName = function (self, ...)
		if select("#", ...) > 0 then
			return Reference.relatedName(self, ...)
		else
			if not self._relatedName then
				self._relatedName = string.replace(self:container():label(), ' ', '_')
			end
			return Reference.relatedName(self)
		end
	end;
}

local OneToOne = Reference:extend{
	__tag = .....".OneToOne";
	backLink = property;
	init = function (self, params)
		params = params or {}
		Reference.init(self, params)
		self:backLink(params.backLink or false)
	end;
	tableName = function (self)
		return self:refModel():tableName()
	end;
	value = function (self, ...)
		if select("#", ...) > 0 then
			return Reference.value(self, ...)
		else
			local container = self:container()
			local db = container:db()
			if db:isA(sql.Driver) then
				if self:backLink() then
					if not self._value and not self._loaded then
						self._loaded = true
						local backRefFieldName = self:backRefFieldName()
						local container = self:container()
						local refModel = self:refModel()
						local val = container:field(refModel:field(backRefFieldName):toField() or container:pkName()):value()
						if val then
							self._value = self:refModel():find{[backRefFieldName] = val}
						end
					end
				else
					if self._value and "table" ~= type(self._value) then
						self._value = self:refModel():find(self._value)
					end
				end
			elseif db:isA(keyvalue.Driver) then
				local value = Reference.value(self)
				if value and "table" ~= type(value) then
					self:value(self:refModel():find(value))
				end
			else
				Exception"unsupported driver"
			end
			return self._value
		end
	end;
	backRefFieldName = function (self)
		return self:refModel():referenceField(self:container(), require(MODULE).OneToOne)
	end;
	createBackLink = function (self)
		return require(MODULE).OneToOne{references=self:container();backLink=not self:backLink();relatedName=self:name();label=self:container():label()}
	end;
	relatedName = function (self, ...)
		if select("#", ...) > 0 then
			return Reference.relatedName(self, ...)
		else
			if not self._relatedName then
				self._relatedName = self:container():label()
			end
			return Reference.relatedName(self)
		end
	end;
}

return {
	Reference=Reference;ManyToMany=ManyToMany;ManyToOne=ManyToOne;
	OneToMany=OneToMany;OneToOne=OneToOne;
}
