local Table, String, Object, Exception = require"Table", require"String", require"ProtOo", require"Exception"
local Debug, io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select = require"Debug", io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select

module(...)

local Select = Object:extend{
	__tag = "Database.Driver.Select",

	init = function (self, db, ...)
		self.db = db
		self.fields = {}
		local i, val, k, v
		for i = 1, select("#", ...) do
			val = select(i, ...)
			if type(val) == "table" then
				for k, v in pairs(val) do
					self.fields[k] = v
				end
			else
				Table.insert(self.fields, val)
			end
		end
		self.tables = {}
		self.conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
		self.joins = {
			inner = {},
			outer = {},
			left = {},
			right = {},
			natural = {},
			full = {},
			cross = {}
		}
		self.joinsUsing = {
			inner = {},
			outer = {},
			left = {},
			right = {},
			full = {}
		}
	end,
	from = function (self, ...)
		local i, val, k, v
		for i = 1, select("#", ...) do
			val = select(i, ...)
			if type(val) == "table" then
				for k, v in pairs(val) do
					self.tables[k] = v
				end
			else
				Table.insert(self.tables, val)
			end
		end
		return self
	end,
	where = function (self, ...) Table.insert(self.conditions.where, {...}) return self end,
	orWhere = function (self, ...) Table.insert(self.conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		local i, val
		for i = 1, select("#", ...) do
			val = select(i, ...)
			Table.insert(self.conditions.order, val)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = to
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self.conditions.limit.from = (page-1)*onPage
		self.conditions.limit.to = page*onPage
		return self
	end,
	join = function (self, ...) Table.insert(self.joins.inner, {...}) return self end,
	joinInner = function (self, ...) Table.insert(self.joins.inner, {...}) return self end,
	joinOuter = function (self, ...) Table.insert(self.joins.outer, {...}) return self end,
	joinLeft = function (self, ...) Table.insert(self.joins.left, {...}) return self end,
	joinRight = function (self, ...) Table.insert(self.joins.right, {...}) return self end,
	joinFull = function (self, ...) Table.insert(self.joins.full, {...}) return self end,
	joinCross = function (self, ...) Table.insert(self.joins.cross, {...}) return self end,
	joinNatural = function (self, ...) Table.insert(self.joins.natural, {...}) return self end,
	joinInnerUsing = function (self, ...) Table.insert(self.joinsUsing.inner, {...}) return self end,
	joinOuterUsing = function (self, ...) Table.insert(self.joinsUsing.outer, {...}) return self end,
	joinLeftUsing = function (self, ...) Table.insert(self.joinsUsing.left, {...}) return self end,
	joinRightUsing = function (self, ...) Table.insert(self.joinsUsing.right, {...}) return self end,
	joinFullUsing = function (self, ...) Table.insert(self.joinsUsing.full, {...}) return self end,
	exec = function (self) return self.db:fetchAll(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local SelectRow = Select:extend{
	__tag = "Database.Driver.SelectRow",
	
	exec = function (self) return self.db:fetchRow(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local SelectCell = SelectRow:extend{
	__tag = "Database.Driver.SelectCell",
	
	exec = function (self) return self.db:fetchCell(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local Insert = Object:extend{
	__tag = "Database.Driver.Insert",
	
	init = function (self, db, fields, ...)
		self.db = db
		self.valuesData = {}
		self.fields = fields
		self.fieldNames = {...}
	end,
	into = function (self, ...) self.table = {...} return self end,
	values = function (self, ...) Table.insert(self.valuesData, {...}) return self end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local InsertRow = Object:extend{
	__tag = "Database.Driver.InsertRow",
	
	init = function (self, db)
		self.db = db
		self.sets = {}
	end,
	into = function (self, table) self.table = table return self end,
	set = function (self, ...) Table.insert(self.sets, {...}) return self end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local Update = Object:extend{
	__tag = "Database.Driver.Update",
	
	init = function (self, db, table)
		self.db = db
		self.table = table
		self.sets = {}
		self.conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
	end,
	set = function (self, ...) Table.insert(self.sets, {...}) return self end,
	where = function (self, ...) Table.insert(self.conditions.where, {...}) return self end,
	orWhere = function (self, ...) Table.insert(self.conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		local i, val
		for i = 1, select("#", ...) do
			val = select(i, ...)
			Table.insert(self.conditions.order, val)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = to
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self.conditions.limit.from = (page-1)*onPage
		self.conditions.limit.to = (page-1)*onPage+1
		return self
	end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local UpdateRow = Update:extend{
	__tag = "Database.Driver.UpdateRow",
	
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = from+1
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = 1
		end
		return self
	end,
	limitPage = Update.maskedMethod,
	__tostring = Object.abstractMethod
}

local Delete = Object:extend{
	__tag = "Database.Driver.Delete",

	init = function (self, db, table)
		self.db = db
		self.conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
	end,
	from = function (self, table) self.table = table return self end,
	where = function (self, ...) Table.insert(self.conditions.where, {...}) return self end,
	orWhere = function (self, ...) Table.insert(self.conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		local i, val
		for i = 1, select("#", ...) do
			val = select(i, ...)
			Table.insert(self.conditions.order, val)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = to
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self.conditions.limit.from = (page-1)*onPage
		self.conditions.limit.to = page*onPage
		return self
	end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local DeleteRow = Delete:extend{
	__tag = "Database.Driver.DeleteRow",
	
	limit = function (self, from, to)
		if to then
			self.conditions.limit.from = from
			self.conditions.limit.to = from+1
		else
			self.conditions.limit.from = 0
			self.conditions.limit.to = 1
		end
		return self
	end,
	limitPage = Delete.maskedMethod,
	__tostring = Object.abstractMethod
}

local DropTable = Object:extend{
	__tag = "Database.Driver.DropTable",
	
	init = function (self, db, table)
		self.db = db
		self.table = table
	end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = function (self) return self.db:processPlaceholders("DROP TABLE ?#;", self.table) end
}

local CreateTable = Object:extend{
	__tag = "Database.Driver.CreateTable",
	
	init = function (self, db, table)
		self.db = db
		self.table = table
		self.fields = {}
		self.unique = {}
		self.options = {}
		self.constraints = {}
	end,
	field = function (self, ...) Table.insert(self.fields, {...}) return self end,
	uniqueTogether = function (self, ...) Table.insert(self.unique, {...}) return self end,
	option = function (self, key, value)
		self.options[key] = value
		return self
	end,
	constraint = function (self, ...) Table.insert(self.constraints, {...}) return self end,
	primaryKey = function (self, ...) self.primaryKeyValue = {...} return self end,
	exec = function (self) return self.db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

return Object:extend{
	__tag = "Database.Driver",

	Exception = Exception:extend{__tag = "Database.Driver.Exception"},
	Select = Select,
	SelectRow = SelectRow,
	SelectCell = SelectCell,
	Insert = Insert,
	InsertRow = InsertRow,
	Update = Update,
	UpdateRow = UpdateRow,
	Delete = Delete,
	DeleteRow = DeleteRow,
	CreateTable = CreateTable,
	DropTable = DropTable,
	
	processPlaceholder = Object.abstractMethod,
	processPlaceholders = function (self, sql, ...)
		local begPos, endPos, res, match, i, lastEnd = 0, 0, {}, nil, 1, 0
		begPos, endPos = String.find(sql, "?[%#davn]?", lastEnd+1)
		while begPos do
			local val = select(i, ...)
			if begPos then
				Table.insert(res, String.slice(sql, lastEnd+1, begPos-1))
				Table.insert(res, self:processPlaceholder(String.slice(sql, begPos, endPos), val))
				lastEnd = endPos
			end
			begPos, endPos = String.find(sql, "?[%#davn]?", lastEnd+1)
			i = i+1
		end
		Table.insert(res, String.slice(sql, lastEnd+1))
		return Table.join(res)
	end,
	fetchAll = function (self, ...)
		local cur, error = self.connection:execute(self:processPlaceholders(...))
		if not cur then
			self.error = error
			return nil
		end
		local res, row = {}, {}
		while cur:fetch(row, "a") do
			Table.insert(res, Table.copy(row))
		end
		return res
	end,
	fetchRow = function (self, ...)
		local cur, error = self.connection:execute(self:processPlaceholders(...))
		if not cur then
			self.error = error
		end
		return cur:fetch({}, "a")
	end,
	fetchCell = function (self, ...)
		local cur, error = self.connection:execute(self:processPlaceholders(...))
		if not cur then
			self.error = error
			return nil
		end
		local res = cur:fetch({}, "a")
		if not res then
			return nil
		end
		local _, v = next(res)
		return v
	end,
	query = function (self, ...)
		--io.write(select(1, ...), "<br />")
		local cur, error = self.connection:execute(self:processPlaceholders(...))
		if not cur then
			self.error = error
			return nil
		end
		if type(cur) == "userdata" then
			return cur:fetch({}, "a")
		end
		return cur
	end,
	getError = function (self) return self.error end,
	select = function (self, ...) return self.Select:new(self, ...) end,
	selectRow = function (self, ...) return self.SelectRow:new(self, ...) end,
	selectCell = function (self, ...) return self.SelectCell:new(self, ...) end,
	insert = function (self, ...) return self.Insert:new(self, ...) end,
	insertRow = function (self, ...) return self.InsertRow:new(self, ...) end,
	update = function (self, ...) return self.Update:new(self, ...) end,
	updateRow = function (self, ...) return self.UpdateRow:new(self, ...) end,
	delete = function (self, ...) return self.Delete:new(self, ...) end,
	deleteRow = function (self, ...) return self.DeleteRow:new(self, ...) end,
	createTable = function (self, ...) return self.CreateTable:new(self, ...) end,
	dropTable = function (self, ...) return self.DropTable:new(self, ...) end
}
