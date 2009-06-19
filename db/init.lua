local table = require"luv.table"
local string = require"luv.string"
local require, io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select = require, io, select, type, next, getmetatable, setmetatable, pairs, unpack, tostring, select
local ipairs = ipairs
local exceptions = require 'luv.exceptions'
local Object, Exception, try = require"luv.oop".Object, exceptions.Exception, exceptions.try

module(...)

local MODULE = ...

local Exception = Exception:extend{__tag = .....".Exception"}

local Factory = Object:extend{
	__tag = .....".Factory",
	new = function (self, dsn)
		local login, pass, port, params = nil, nil, nil, {}
		local driver, host, database, paramsStr = string.split(dsn, "://", "/", "?")
		login, host = string.split(host, "@")
		login, pass = string.split(login, ":")
		host, port = string.split(host, ":")
		paramsStr = string.split(paramsStr, "&")
		if paramsStr then
			for _, v in ipairs(paramsStr) do
				local key, val = string.split(v, "=")
				params[key] = val
			end
		end
		return require(MODULE.."."..driver).Driver(host, login, pass, database, port, params)
	end
}

local Select = Object:extend{
	__tag = .....".Select",
	init = function (self, db, ...)
		self._db = db
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
		local mt = getmetatable(self) or {}
		mt.__call = function (self, ...)
			if not self._values then
				self:_evaluate()
			end
			return ipairs(self._values or {}, ...)
		end
	end,
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
	end,
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
	end,
	where = function (self, ...) table.insert(self._conditions.where, {...}) return self end,
	orWhere = function (self, ...) table.insert(self._conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._conditions.order, v)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = to
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self._conditions.limit.from = (page-1)*onPage
		self._conditions.limit.to = page*onPage
		return self
	end,
	-- TODO: Make it protected
	joinInternalProcess = function (self, joinType, joinTable, condition, fields)
		local tbl = joinTable
		if "table" == type(tbl) then
			tbl = next(tbl)
		end
		-- Condition
		if "table" == type(condition) then
			condition = self._db:processPlaceholders (unpack(condition))
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
					break
				end
			end
		end
		if not founded then
			table.insert(joinType, {joinTable, condition})
		end
		-- Fields
		--[[if fields then
			self:fields(fields)
		else
			self:fields(tbl..".*")
		end]]
	end,
	join = function (self, ...)
		return self:joinInner(...)
	end,
	joinInner = function (self, ...)
		self:joinInternalProcess(self._joins.inner, ...)
		return self
	end,
	joinOuter = function (self, ...) table.insert(self._joins.outer, {...}) return self end,
	joinLeft = function (self, ...) table.insert(self._joins.left, {...}) return self end,
	joinRight = function (self, ...) table.insert(self._joins.right, {...}) return self end,
	joinFull = function (self, ...) table.insert(self._joins.full, {...}) return self end,
	joinCross = function (self, ...) table.insert(self._joins.cross, {...}) return self end,
	joinNatural = function (self, ...) table.insert(self._joins.natural, {...}) return self end,
	joinInnerUsing = function (self, ...) table.insert(self._joinsUsing.inner, {...}) return self end,
	joinOuterUsing = function (self, ...) table.insert(self._joinsUsing.outer, {...}) return self end,
	joinLeftUsing = function (self, ...) table.insert(self._joinsUsing.left, {...}) return self end,
	joinRightUsing = function (self, ...) table.insert(self._joinsUsing.right, {...}) return self end,
	joinFullUsing = function (self, ...) table.insert(self._joinsUsing.full, {...}) return self end,
	_evaluate = function (self)
		self._values = self._db:fetchAll(tostring(self))
	end;
	exec = function (self)
		if not self._values then
			self:_evaluate()
		end
		return self._values
	end;
	__tostring = Object.abstractMethod
}

local SelectRow = Select:extend{
	__tag = .....".Driver.SelectRow";
	exec = function (self) return self._db:fetchRow(tostring(self)) end;
	__tostring = Object.abstractMethod;
}

local SelectCell = SelectRow:extend{
	__tag = .....".Driver.SelectCell";
	exec = function (self) return self._db:fetchCell(tostring(self)) end;
	__tostring = Object.abstractMethod;
}

local Insert = Object:extend{
	__tag = .....".Driver.Insert",
	init = function (self, db, fields, ...)
		self._db = db
		self._valuesData = {}
		self._fields = fields
		self._fieldNames = {...}
	end,
	into = function (self, ...) self._table = {...} return self end,
	values = function (self, ...) table.insert(self._valuesData, {...}) return self end,
	exec = function (self) return self._db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local InsertRow = Object:extend{
	__tag = .....".Driver.InsertRow",
	init = function (self, db)
		self._db = db
		self._sets = {}
	end,
	into = function (self, table) self._table = table return self end,
	set = function (self, ...) table.insert(self._sets, {...}) return self end,
	exec = function (self) return self._db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
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
	end,
	set = function (self, ...) table.insert(self._sets, {...}) return self end,
	where = function (self, ...) table.insert(self._conditions.where, {...}) return self end,
	orWhere = function (self, ...) table.insert(self._conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._conditions.order, v)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = to
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self._conditions.limit.from = (page-1)*onPage
		self._conditions.limit.to = (page-1)*onPage+1
		return self
	end,
	exec = function (self) return self._db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
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
	end,
	limitPage = Update.maskedMethod,
	__tostring = Object.abstractMethod
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
	end,
	from = function (self, table) self._table = table return self end,
	where = function (self, ...) table.insert(self._conditions.where, {...}) return self end,
	orWhere = function (self, ...) table.insert(self._conditions.orWhere, {...}) return self end,
	order = function (self, ...)
		for _, v in ipairs{select(1, ...)} do
			table.insert(self._conditions.order, v)
		end
		return self
	end,
	limit = function (self, from, to)
		if to then
			self._conditions.limit.from = from
			self._conditions.limit.to = to
		else
			self._conditions.limit.from = 0
			self._conditions.limit.to = from
		end
		return self
	end,
	limitPage = function (self, page, onPage)
		self._conditions.limit.from = (page-1)*onPage
		self._conditions.limit.to = page*onPage
		return self
	end,
	exec = function (self) return self._db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
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
	end,
	limitPage = Delete.maskedMethod,
	__tostring = Object.abstractMethod
}

local DropTable = Object:extend{
	__tag = .....".Driver.DropTable",
	init = function (self, db, table)
		self._db = db
		self._table = table
	end,
	exec = function (self) return self._db:query(tostring(self)) end,
	__tostring = function (self) return self._db:processPlaceholders("DROP TABLE ?#;", self._table) end
}

local CreateTable = Object:extend{
	__tag = .....".Driver.CreateTable",
	init = function (self, db, table)
		self._db = db
		self._table = table
		self._fields = {}
		self._unique = {}
		self._options = {}
		self._constraints = {}
	end,
	field = function (self, ...) table.insert(self._fields, {...}) return self end,
	uniqueTogether = function (self, ...) table.insert(self._unique, {...}) return self end,
	option = function (self, key, value)
		self._options[key] = value
		return self
	end,
	constraint = function (self, ...) table.insert(self._constraints, {...}) return self end,
	primaryKey = function (self, ...) self._primaryKeyValue = {...} return self end,
	exec = function (self) return self._db:query(tostring(self)) end,
	__tostring = Object.abstractMethod
}

local Driver = Object:extend{
	__tag = .....".Driver",
	Exception = Exception:extend{__tag = .....".Driver.Exception"},
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
	-- Logger
	_logger = function (sql, result, time) end;
	getLogger = function (self) return self._logger end;
	setLogger = function (self, logger) self._logger = logger return self end;
	processPlaceholder = Object.abstractMethod,
	processPlaceholders = function (self, sql, ...)
		local begPos, endPos, res, match, i, lastEnd = 0, 0, {}, nil, 1, 0
		begPos, endPos = string.find(sql, "?[%#davnq]?", lastEnd+1)
		while begPos do
			local val = select(i, ...)
			if begPos then
				table.insert(res, string.slice(sql, lastEnd+1, begPos-1))
				table.insert(res, self:processPlaceholder(string.slice(sql, begPos, endPos), val))
				lastEnd = endPos
			end
			begPos, endPos = string.find(sql, "?[%#davnq]?", lastEnd+1)
			i = i+1
		end
		table.insert(res, string.slice(sql, lastEnd+1))
		return table.join(res)
	end,
	fetchAll = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql.." return error: "..error)
			return nil
		end
		local res, row = {}, {}
		while cur:fetch(row, "a") do
			table.insert(res, table.copy(row))
		end
		self._logger(rawSql.." return "..#res.." rows")
		return res
	end,
	fetchRow = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql.." return error: "..error)
			return nil
		end
		local res = cur:fetch({}, "a")
		self._logger(rawSql.." return row")
		return res
	end,
	fetchCell = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql.." return error: "..error)
			return nil
		end
		local res = cur:fetch({}, "a")
		if not res then
			self._logger(rawSql.." return nil")
			return nil
		end
		local _, v = next(res)
		self._logger(rawSql.." return "..v)
		return v
	end,
	beginTransaction = function (self) self:query "BEGIN;" return self end;
	commit = function (self) self:query "COMMIT;" return self end;
	rollback = function (self) self:query "ROLLBACK;" return self end;
	query = function (self, ...)
		local rawSql = self:processPlaceholders(...)
		local cur, error = self._connection:execute(rawSql)
		if not cur then
			self._error = error
			self._logger(rawSql.." return error: "..error)
			return nil
		end
		if type(cur) == "userdata" then
			local res = cur:fetch({}, "a")
			self._logger(rawSql.." return "..#res.." rows")
			return res
		end
		self._logger(rawSql.." return "..cur)
		return cur
	end,
	getLastInsertId = Object.abstractMethod,
	getError = function (self) return self._error end
}

return {
	Exception = Exception,
	Factory = Factory,
	Driver = Driver
}
