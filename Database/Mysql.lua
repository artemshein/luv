local Driver, LuaSql, String, Table = require"Database.Driver", require"luasql.mysql", require"String", require"Table"
local Debug, io, tostring, tonumber, pairs, ipairs, type, getmetatable, unpack, next = require"Debug", io, tostring, tonumber, pairs, ipairs, type, getmetatable, unpack, next

module(...)

local Select = Driver.Select:extend{
	__tag = "Database.Mysql.Select",

	__tostring = function (self)
		return
			"SELECT "
			..self.db:constructFields(self.fieldsVal)
			..self.db:constructFrom(self.tables)
			..self.db:constructJoins(self.joins)
			..self.db:constructWhere(self.conditions.where, self.conditions.orWhere)
			..self.db:constructOrder(self.conditions.order)
			..self.db:constructLimit(self.conditions.limit)
			..";"
	end
}

local SelectRow = Driver.SelectRow:extend{
	__tag = "Database.Mysql.SelectRow",

	__tostring = getmetatable(Select).__tostring
}

local SelectCell = Driver.SelectCell:extend{
	__tag = "Database.Mysql.SelectCell",

	__tostring = getmetatable(SelectRow).__tostring
}

local Insert = Driver.Insert:extend{
	__tag = "Database.Mysql.Insert",

	__tostring = function (self)
		return
			"INSERT INTO "
			..self.db:processPlaceholder("?#", self.table)
			.." ("..self.db:constructFields(self.fieldNames)..") VALUES "
			..self.db:constructValues(self.fields, self.valuesData)
			..";"
	end
}

local InsertRow = Driver.InsertRow:extend{
	__tag = "Database.Mysql.InsertRow",

	__tostring = function (self)
		return
			"INSERT INTO "
			..self.db:processPlaceholder("?#", self.table)
			..self.db:constructSet(self.sets)
			..";"
	end
} 

local Update = Driver.Update:extend{
	__tag = "Database.Mysql.Update",

	__tostring = function (self)
		return
			"UPDATE "
			..self.db:processPlaceholder("?#", self.table)
			..self.db:constructSet(self.sets)
			..self.db:constructWhere(self.conditions.where, self.conditions.orWhere)
			..self.db:constructOrder(self.conditions.order)
			..self.db:constructLimit(self.conditions.limit)
			..";"
	end
}

local UpdateRow = Driver.UpdateRow:extend{
	__tag = "Database.Mysql.UpdateRow",

	__tostring = getmetatable(Update).__tostring
}

local Delete = Driver.Delete:extend{
	__tag = "Database.Mysql.Delete",

	__tostring = function (self)
		return
			"DELETE FROM "
			..self.db:processPlaceholder("?#", self.table)
			..self.db:constructWhere(self.conditions.where, self.conditions.orWhere)
			..self.db:constructOrder(self.conditions.order)
			..self.db:constructLimit(self.conditions.limit)
			..";"
	end
}

local DeleteRow = Driver.DeleteRow:extend{
	__tag = "Database.Mysql.DeleteRow",

	__tostring = getmetatable(Delete).__tostring
}

local CreateTable = Driver.CreateTable:extend{
	__tag = "Database.Mysql.CreateTable",

	init = function (self, ...)
		Driver.CreateTable.init(self, ...)
		self.options = { ["charset"] = "utf8", ["engine"] = "InnoDB"}
	end,
	__tostring = function (self)
		return
			"CREATE TABLE "
			..self.db:processPlaceholder("?#", self.table)
			.." ("
			..self.db:constructFieldsDefinition(self.fields)
			..self.db:constructPrimaryKey(self.primaryKeyValue)
			..self.db:constructUnique(self.unique)
			..self.db:constructConstraints(self.constraints)
			..")"
			..self.db:constructOptions(self.options)
			..";"
	end
}

local DropTable = Driver.DropTable:extend{
	__tag = "Database.Mysql.DropTable",

	__tostring = function (self)
		return self.db:processPlaceholders("DROP TABLE ?#;", self.table)
	end
}

return Driver:extend{
	__tag = "Database.Mysql",

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

	init = function (self, host, login, pass, database, port, params)
		local mysql = LuaSql.mysql()
		self.connection = mysql:connect(database, login, pass, host, port)
		if not self.connection then
			Driver.Exception("Could not connect to "..host.."!"):throw()
		end
	end,
	getLastInsertId = function (self)
		local res = self:query("SELECT LAST_INSERT_ID() AS `i`;")
		if not res then
			return nil
		end
		return tonumber(res.i)
	end,
	processPlaceholder = function (self, placeholder, value)
		if placeholder == "?" then
			return "'"..String.gsub(tostring(value), "'", "\\'").."'"
		elseif placeholder == "?d" then
			local num = tonumber(value)
			if not num then Driver.Exception"Not a valid number given!":throw() end
			return tostring(num)
		elseif placeholder == "?#" then
			if type(value) == "table" then
				local _, v, res = nil, nil, ""
				for _, v in pairs(value) do
					if res ~= "" then res = res..", " end
					res = res..self:processPlaceholder("?#", v)
				end
				return res
			else
				local val = tostring(value)
				if String.find(val, "(", 1, true) then
					return val
				elseif String.find(val, ".", 1, true) then
					local before, after = String.split(val, ".")
					if "*" == after then
						return self:processPlaceholder("?#", before)..".*"
					else
						return self:processPlaceholder("?#", before).."."..self:processPlaceholder("?#", after)
					end
				else
					return "`"..String.gsub(val, "`", "``").."`"
				end
			end
		elseif placeholder == "?n" then
			local tVal = type(value)
			if (tVal == "number" and value ~= 0) or tVal == "boolean" then
				return self:processPlaceholder("?d", value)
			elseif tVal == "string" or tVal == "table" then
				local str = tostring(value)
				if str ~= "" then
					return self:processPlaceholder("?", str)
				else
					return "NULL"
				end
			else
				return "NULL"
			end
		elseif placeholder == "?a" then
			local _, v, res = nil, nil, ""
			for _, v in ipairs(value) do
				if res ~= "" then res = res..", " end
				if type(v) == "number" then
					res = res..self:processPlaceholder("?d", v)
				elseif type(v) == "string" then
					res = res..self:processPlaceholder("?", v)
				else
					Driver.Exception:new"Invalid value type!":throw()
				end
			end
			return res
		elseif placeholder == "?v" then
			local k, v, res = nil, nil, ""
			for k, v in pairs(value) do
				if res ~= "" then res = res..", " end
				res = res..self:processPlaceholder("?#", k)
				if type(v) == "number" then
					res = res.."="..self:processPlaceholder("?d", v)
				elseif type(v) == "string" then
					res = res.."="..self:processPlaceholder("?", v)
				else
					Driver.Exception"Invalid value type!":throw()
				end
			end
			return res
		end
		Driver.Exception("Invalid placeholder \""..placeholder.."\"!"):throw()
	end,
	constructFields = function (self, fields)
		local k, v, res = nil, nil, {}
		for k, v in pairs(fields) do
			if type(k) == "string" then
				res[k] = self:processPlaceholder("?#", v).." AS "..self:processPlaceholder("?#", k)
			else
				res[k] = self:processPlaceholder("?#", v)
			end
		end
		res = Table.join(res, ", ")
		if res == "" then return "*" end
		return res
	end,
	constructFrom = function (self, from)
		local k, v, res = nil, nil, {}
		for k, v in pairs(from) do
			if type(k) == "string" then
				res[k] = self:processPlaceholder("?#", v).." AS "..self:processPlaceholder("?#", k)
			else
				res[k] = self:processPlaceholder("?#", v)
			end
		end
		return " FROM "..Table.join(res, ", ")
	end,
	constructWhere = function (self, where, orWhere)
		local k, v, w, ow, res, res2 = nil, nil, {}, {}, nil, nil
		for k, v in pairs(where) do
			Table.insert(w, self:processPlaceholders(unpack(v)))
		end
		for k, v in pairs(orWhere) do
			Table.insert(ow, self:processPlaceholders(unpack(v)))
		end
		res = Table.join(w, ") AND (")
		if res ~= "" then
			res = " WHERE ("..res..")"
		end
		res2 = Table.join(ow, ") OR (")
		if res2 ~= "" then
			if res ~= "" then
				res2 = " OR ("..res2..")"
			else
				res2 = " WHERE ("..res2..")"
			end
		end
		return res..res2
	end,
	constructOrder = function (self, order)
		local k, v, res = nil, nil, {}
		for k, v in pairs(order) do
			if v == "*" then
				Table.insert(res, "RAND()")
			elseif String.beginsWith(v, "-") then
				Table.insert(res, self:processPlaceholder("?#", String.slice(v, 2)).." DESC")
			else
				Table.insert(res, self:processPlaceholder("?#", v).." ASC")
			end
		end
		res = Table.join(res, ", ")
		if res == "" then return "" end
		return " ORDER BY "..res
	end,
	constructLimit = function (self, limit)
		if not limit.to then
			if not limit.from then
				return ""
			else
				return " LIMIT "..limit.from
			end
		end
		if limit.from == 0 then
			return " LIMIT "..limit.to
		else
			return " LIMIT "..(limit.to-limit.from).." OFFSET "..limit.from
		end
	end,
	constructSet = function (self, sets)
		local k, v, res = nil, nil, {}
		for k, v in pairs(sets) do
			res[k] = self:processPlaceholders(unpack(v))
		end
		return " SET "..Table.join(res, ", ")
	end,
	constructValues = function (self, placeholders, values)
		local res, _, v = {}
		for _, v in pairs(values) do
			Table.insert(res, self:processPlaceholders(placeholders, unpack(v)))
		end
		return "("..Table.join(res, "), (")..")"
	end,
	constructFieldsDefinition = function (self, fields)
		local res, _, v, fld = {}
		for _, v in pairs(fields) do
			fld = self:processPlaceholder("?#", v[1]).." "..v[2]
			local options = v[3] or {}
			if options.primaryKey then fld = fld.." PRIMARY KEY" end
			if options.serial then fld = fld.." AUTO_INCREMENT" end
			if options.null then fld = fld.." NULL" else fld = fld.." NOT NULL" end
			if options.unique then fld = fld.." UNIQUE" end
			if options.default then
				if type(options.default) == "string" then
					if options.default == "NULL" then
						fld = fld.." DEFAULT NULL"
					else
						fld = fld.." DEFAULT "..self:processPlaceholder("?", options.default)
					end
				elseif type(options.default) == "number" then
					fld = fld..self:processPlaceholder("?d", options.default)
				else
					Driver.Exception("Unsupported default option type \""..type(options.default).."\"!"):throw()
				end
			end
			Table.insert(res, fld)
		end
		return Table.join(res, ", ")
	end,
	constructPrimaryKey = function (self, primary)
		local res, _, v = {}
		if not primary then return "" end
		for _, v in pairs(primary) do
			Table.insert(res, self:processPlaceholder("?#", v))
		end
		return ", PRIMARY KEY ("..Table.join(res, ", ")..")"
	end,
	constructUnique = function (self, unique)
		local res, _, v, uniq, v2 = {}
		if not unique then return "" end
		for _, v in pairs(unique) do
			uniq = {}
			for _, v2 in pairs(v) do
				Table.insert(uniq, self:processPlaceholder("?#", v2))
			end
			Table.insert(res, ", UNIQUE ("..Table.join(uniq, ", ")..")")
		end
		return Table.join(res, ",")
	end,
	constructConstraints = function (self, refs)
		local _, v, res, ref = nil, nil, {}
		if not refs then return "" end
		for _, v in pairs(refs) do
			ref = self:processPlaceholders(", CONSTRAINT FOREIGN KEY (?#) REFERENCES ?# (?#)", v[1], v[2], v[3])
			if v[4] then ref = ref.." ON UPDATE "..v[4] end
			if v[5] then ref = ref.." ON DELETE "..v[5] end
			Table.insert(res, ref)
		end
		return Table.join(res)
	end,
	constructOptions = function (self, options)
		local res, k, v = {}
		if not options then return "" end
		for k, v in pairs(options) do
			if k == "charset" then
				Table.insert(res, "CHARACTER SET "..v)
			elseif k == "engine" then
				Table.insert(res, "ENGINE = "..v)
			else
				Exception("Unsupported option "..k.."!"):throw()
			end
		end
		return " "..Table.join(res, " ")
	end,
	constructJoins = function (self, joins)
		local res, k, v, table = {}
		for k, v in pairs(joins.inner) do
			if "table" == type(v[1]) then
				local name, table = next(v[1])
				Table.insert(res, self:processPlaceholders("JOIN ?# AS ?# ON "..v[2], table, name))
			else
				Table.insert(res, self:processPlaceholders("JOIN ?# ON "..v[2], v[1]))
			end
		end
		res = Table.join(res, " ")
		if "" ~= res then
			return " "..res
		else
			return ""
		end
	end
}
