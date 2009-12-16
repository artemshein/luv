local table = require"luv.table"
local string = require"luv.string"
local require, io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select = require, io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select
local ipairs = ipairs
local exceptions = require"luv.exceptions"
local Object, Exception, try = require"luv.oop".Object, exceptions.Exception, exceptions.try

module(...)

local MODULE = (...)
local property = Object.property
local abstract = Object.abstractMethod

local Factory = Object:extend{
	__tag = .....".Factory";
	new = function (self, dsn)
		local login, pass, port, params = nil, nil, nil, {}
		local driver, host, database, paramsStr = dsn:split("://", "/", "?")
		login, host = host:split"@"
		login, pass = login:split":"
		host, port = host:split":"
		if paramsStr then paramsStr = paramsStr:split"&" end
		if paramsStr then
			for _, v in ipairs(paramsStr) do
				local key, val = v:split"="
				params[key] = val
			end
		end
		return require(MODULE.."."..driver).Driver(host, login, pass, database, port, params)
	end;
}

local Select = Object:extend{
	__tag = .....".Select";
	__tostring = abstract;
	__call = function (self, ...)
		if not self._values then
			self:_evaluate()
		end
		return self._values
	end;
	_evaluate = function (self)
		self._values = self:db():fetchAll(tostring(self))
	end;
	db = property;
	init = function (self, db, ...)
		self:db(db)
		self._fields = {}
		self:fields(...)
		self._tables = {}
		self._conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
		self._joins = {
			inner = {},
			outer = {},
			left = {},
			right = {},
			natural = {},
			full = {},
			cross = {}
		}
		self._joinsUsing = {
			inner = {},
			outer = {},
			left = {},
			right = {},
			full = {}
		}
	end;
	from = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			if type(v) == "table" then
				for k, v2 in pairs(v) do
					self._tables[k] = v2
				end
			else
				table.insert(self._tables, v)
			end
		end
		return self
	end;
	fields = function (self, ...)
		if 0 == select("#", ...) then
			return self
		end
		for _, v in ipairs{select(1, ...)} do
			if type(v) == "table" then
				for k, v2 in pairs(v) do
					if not table.find(self._fields, v2) then
						self._fields[k] = v2
					end
				end
			else
				if not table.find(self._fields, v) then
					table.insert(self._fields, v)
				end
			end
		end
		return self
	end;
	where = function (self, ...) table.insert(self._conditions.where, {...}) return self end;
	orWhere = function (self, ...) table.insert(self._conditions.orWhere, {...}) return self end;
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._conditions.order, v)
		end
		return self
	end;
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = to
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = from
		end
		return self
	end;
	limitPage = function (self, page, onPage)
		self._conditions.limit.from = (page-1)*onPage
		self._conditions.limit.to = page*onPage
		return self
	end;
	_joinInternalProcess = function (self, joinType, joinTable, condition, fields)
		local tbl = joinTable
		if "table" == type(tbl) then
			tbl = next(tbl)
		end
		-- Condition
		if "table" == type(condition) then
			condition = self._db:processPlaceholders(unpack(condition))
		end
		local founded
		for _, v in pairs(self._tables) do
			if v == joinTable then
				founded = true
				break
			end
		end
		if not founded then
			for _, v in ipairs(joinType) do
				if v[1] == joinTable then
					founded = true
					v[2] = "("..v[2].." OR "..condition..")"
					break
				end
			end
		end
		if not founded then
			table.insert(joinType, {joinTable, condition})
		end
	end;
	join = function (self, ...)
		return self:joinInner(...)
	end;
	joinInner = function (self, ...)
		self:_joinInternalProcess(self._joins.inner, ...)
		return self
	end;
	joinOuter = function (self, ...) table.insert(self._joins.outer, {...}) return self end;
	joinLeft = function (self, ...) table.insert(self._joins.left, {...}) return self end;
	joinRight = function (self, ...) table.insert(self._joins.right, {...}) return self end;
	joinFull = function (self, ...) table.insert(self._joins.full, {...}) return self end;
	joinCross = function (self, ...) table.insert(self._joins.cross, {...}) return self end;
	joinNatural = function (self, ...) table.insert(self._joins.natural, {...}) return self end;
	joinInnerUsing = function (self, ...) table.insert(self._joinsUsing.inner, {...}) return self end;
	joinOuterUsing = function (self, ...) table.insert(self._joinsUsing.outer, {...}) return self end;
	joinLeftUsing = function (self, ...) table.insert(self._joinsUsing.left, {...}) return self end;
	joinRightUsing = function (self, ...) table.insert(self._joinsUsing.right, {...}) return self end;
	joinFullUsing = function (self, ...) table.insert(self._joinsUsing.full, {...}) return self end;
}

local SelectRow = Select:extend{
	__tag = .....".Driver.SelectRow";
	_evaluate = function (self) self._values = self._db:fetchRow(tostring(self)) end;
}

local SelectCell = SelectRow:extend{
	__tag = .....".Driver.SelectCell";
	_evaluate = function (self) self._values = self._db:fetchCell(tostring(self)) end;
}

local Insert = Object:extend{
	__tag = .....".Driver.Insert",
	init = function (self, db, fields, ...)
		self._db = db
		self._valuesData = {}
		self._fields = fields
		self._fieldNames = {...}
	end;
	into = function (self, ...) self._table = {...} return self end;
	values = function (self, ...) table.insert(self._valuesData, {...}) return self end;
	_evaluate = function (self) return self._db:query(tostring(self)) end;
	__call = function (self) return self:_evaluate() end;
	__tostring = Object.abstractMethod;
}

local InsertRow = Object:extend{
	__tag = .....".Driver.InsertRow",
	init = function (self, db)
		self._db = db
		self._sets = {}
	end;
	into = function (self, table) self._table = table return self end;
	set = function (self, ...) table.insert(self._sets, {...}) return self end;
	_evaluate = function (self) return self._db:query(tostring(self)) end;
	__tostring = Object.abstractMethod;
	__call = function (self) return self:_evaluate() end;
}

local Update = Object:extend{
	__tag = .....".Driver.Update",
	init = function (self, db, table)
		self._db = db
		self._table = table
		self._sets = {}
		self._conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
	end;
	set = function (self, ...) table.insert(self._sets, {...}) return self end;
	where = function (self, ...) table.insert(self._conditions.where, {...}) return self end;
	orWhere = function (self, ...) table.insert(self._conditions.orWhere, {...}) return self end;
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._conditions.order, v)
		end
		return self
	end;
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = to
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = from
		end
		return self
	end;
	limitPage = function (self, page, onPage)
		self._conditions.limit.from = (page-1)*onPage
		self._conditions.limit.to = (page-1)*onPage+1
		return self
	end;
	_evaluate = function (self) return self._db:query(tostring(self)) end;
	__tostring = Object.abstractMethod;
	__call = function (self) return self:_evaluate() end;
}

local UpdateRow = Update:extend{
	__tag = .....".Driver.UpdateRow",
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = from+1
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = 1
		end
		return self
	end;
	limitPage = Update.maskedMethod;
}

local Delete = Object:extend{
	__tag = .....".Driver.Delete",
	init = function (self, db, table)
		self._db = db
		self._conditions = {
			where = {},
			orWhere = {},
			order = {},
			limit = {}
		}
	end;
	from = function (self, table) self._table = table return self end;
	where = function (self, ...) table.insert(self._conditions.where, {...}) return self end;
	orWhere = function (self, ...) table.insert(self._conditions.orWhere, {...}) return self end;
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._conditions.order, v)
		end
		return self
	end;
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = to
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = from
		end
		return self
	end;
	limitPage = function (self, page, onPage)
		self._conditions.limit.from = (page-1)*onPage
		self._conditions.limit.to = page*onPage
		return self
	end;
	_evaluate = function (self) return self._db:query(tostring(self)) end;
	__tostring = Object.abstractMethod;
	__call = function (self) return self:_evaluate() end;
}

local DeleteRow = Delete:extend{
	__tag = .....".Driver.DeleteRow",
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = from+1
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = 1
		end
		return self
	end;
	limitPage = Delete.maskedMethod;
}

local DropTable = Object:extend{
	__tag = .....".Driver.DropTable",
	init = function (self, db, table)
		self._db = db
		self._table = table
	end;
	_evaluate = function (self) return self._db:query(tostring(self)) end;
	__tostring = function (self) return self._db:processPlaceholders("DROP TABLE ?#;", self._table) end;
	__call = function (self) return self:_evaluate() end;
}

local CreateTable = Object:extend{
	__tag = .....".Driver.CreateTable";
	__tostring = abstract;
	__call = function (self) return self:_evaluate() end;
	_evaluate = function (self) return self:db():query(tostring(self)) end;
	db = property;
	init = function (self, db, table)
		self:db(db)
		self._table = table
		self._fields = {}
		self._unique = {}
		self._options = {}
		self._constraints = {}
	end;
	field = function (self, ...) table.insert(self._fields, {...}) return self end;
	uniqueTogether = function (self, ...) table.insert(self._unique, {...}) return self end;
	option = function (self, key, value)
		self._options[key] = value
		return self
	end;
	constraint = function (self, ...) table.insert(self._constraints, {...}) return self end;
	primaryKey = function (self, ...) self._primaryKeyValue = {...} return self end;
}

local AddColumn = Object:extend{
	__tag = .....".Driver.AddColumn";
	__tostring = abstract;
	__call = function (self) return self:_evaluate() end;
	_evaluate = function (self) return self:db():query(tostring(self)) end;
	db = property;
	init = function (self, db, table, ...)
		self:db(db)
		self._table = table
		self._column = {...}
	end;
}

local RemoveColumn = Object:extend{
	__tag = .....".Driver.RemoveColumn";
	__tostring = abstract;
	__call = function (self) return self:_evaluate() end;
	_evaluate = function (self) return self:db():query(tostring(self)) end;
	db = property;
	init = function (self, db, table, column)
		self:db(db)
		self._table = table
		self._column = column
	end;
}

local SqlDriver = Object:extend{
	__tag = .....".SqlDriver",
	Exception = Exception:extend{__tag = .....".SqlDriver.Exception"};
	Select = Select;
	SelectRow = SelectRow;
	SelectCell = SelectCell;
	Insert = Insert;
	InsertRow = InsertRow;
	Update = Update;
	UpdateRow = UpdateRow;
	Delete = Delete;
	DeleteRow = DeleteRow;
	CreateTable = CreateTable;
	DropTable = DropTable;
	AddColumn = AddColumn;
	RemoveColumn = RemoveColumn;
	_logger = function (sql, result, time) end;
	logger = Object.property;
	processPlaceholder = Object.abstractMethod;
	processPlaceholders = function (self, sql, ...)
		local begPos, endPos, res, match, i, lastEnd = 0, 0, {}, nil, 1, 0
		begPos, endPos = sql:find("?[%#davnq]?", lastEnd+1)
		while begPos do
			local val = select(i, ...)
			if begPos then
				table.insert(res, sql:slice(lastEnd+1, begPos-1))
				table.insert(res, self:processPlaceholder(sql:slice(begPos, endPos), val))
				lastEnd = endPos
			end
			begPos, endPos = sql:find("?[%#davnq]?", lastEnd+1)
			i = i+1
		end
		table.insert(res, sql:slice(lastEnd+1))
		return table.join(res)
	end;
	fetchAll = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql, "error: "..error)
			return nil
		end
		local res, row = {}, {}
		while cur:fetch(row, "a") do
			table.insert(res, table.copy(row))
		end
		self._logger(rawSql, res)
		return res
	end;
	fetchRow = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql, "error: "..error)
			return nil
		end
		local res = cur:fetch({}, "a")
		self._logger(rawSql, res)
		return res
	end;
	fetchCell = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql, "error: "..error)
			return nil
		end
		local res = cur:fetch({}, "a")
		if not res then
			self._logger(rawSql)
			return nil
		end
		local _, v = next(res)
		self._logger(rawSql, v)
		return v
	end;
	beginTransaction = function (self) self:query"BEGIN;" return self end;
	commit = function (self) self:query"COMMIT;" return self end;
	rollback = function (self) self:query"ROLLBACK;" return self end;
	query = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql, "error: "..error)
			return nil
		end
		if type(cur) == "userdata" then
			local res = cur:fetch({}, "a")
			self._logger(rawSql, res)
			return res
		end
		self._logger(rawSql, cur)
		return cur
	end;
	lastInsertId = Object.abstractMethod;
	error = function (self) return self._error end;
}

local KeyValueDriver = Object:extend{
	__tag = .....".KeyValueDriver",
	Exception = Exception:extend{__tag = .....".KeyValueDriver.Exception"};
	_logger = function () end;
	logger = Object.property;
	get = abstract;
	set = abstract;
	del = abstract;
	incr = abstract;
	decr = abstract;
	exists = absrtract;
	flush = abstract;
	close = abstract;
	error = function (self) return self._error end;
}

return {Factory=Factory;SqlDriver=SqlDriver;KeyValueDriver=KeyValueDriver} 
