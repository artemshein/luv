require"luv.string"
require"luv.table"
require"luv.debug"
local debug, string, table, io, tostring, tonumber, pairs, ipairs, type, getmetatable, unpack, next = debug, string, table, io, tostring, tonumber, pairs, ipairs, type, getmetatable, unpack, next
local Driver, LuaSql = require"luv.db".Driver, require"luasql.mysql"

module(...)

local Select = Driver.Select:extend{
	__tag = .....".Select",
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
	__tag = .....".SelectRow",
	__tostring = getmetatable(Select).__tostring
}

local SelectCell = Driver.SelectCell:extend{
	__tag = .....".SelectCell",
	__tostring = getmetatable(SelectRow).__tostring
}

local Insert = Driver.Insert:extend{
	__tag = .....".Insert",
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
	__tag = .....".InsertRow",
	__tostring = function (self)
		return
			"INSERT INTO "
			..self.db:processPlaceholder("?#", self.table)
			..self.db:constructSet(self.sets)
			..";"
	end
} 

local Update = Driver.Update:extend{
	__tag = .....".Update",
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
	__tag = .....".UpdateRow",
	__tostring = getmetatable(Update).__tostring
}

local Delete = Driver.Delete:extend{
	__tag = .....".Delete",
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
	__tag = .....".DeleteRow",
	__tostring = getmetatable(Delete).__tostring
}

local CreateTable = Driver.CreateTable:extend{
	__tag = .....".CreateTable",
	init = function (self, ...)
		Driver.CreateTable.init(self, ...)
		self.options = {charset="utf8", engine="InnoDB"}
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
	__tag = .....".DropTable",
	__tostring = function (self)
		return self.db:processPlaceholders("DROP TABLE ?#;", self.table)
	end
}

local MysqlDriver = Driver:extend{
	__tag = .....".Driver",
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
		self.connection, error = mysql:connect(database, login, pass, host, port)
		if not self.connection then
			Driver.Exception("Could not connect to "..login.."@"..host.." (using password: "..(pass and "yes" or "no").."): "..error):throw()
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
		if placeholder == "?q" then
			return "?"
		elseif placeholder == "?" then
			return "'"..string.gsub(tostring(value), "['?]", {["'"]="\\'";["?"]="?q"}).."'"
		elseif placeholder == "?d" then
			local num
			if nil == type(value) then
				num = 0
			elseif "boolean" == type(value) then
				num = value and 1 or 0
			else
				num = tonumber(value)
			end
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
				if string.find(val, "(", 1, true) then
					return val
				elseif string.find(val, ".", 1, true) then
					local before, after = string.split(val, ".")
					if "*" == after then
						return self:processPlaceholder("?#", before)..".*"
					else
						return self:processPlaceholder("?#", before).."."..self:processPlaceholder("?#", after)
					end
				else
					return "`"..string.gsub(val, "`", "``").."`"
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
					Driver.Exception"Invalid value type!":throw()
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
		res = table.join(res, ", ")
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
		return " FROM "..table.join(res, ", ")
	end,
	constructWhere = function (self, where, orWhere)
		local k, v, w, ow, res, res2 = nil, nil, {}, {}, nil, nil
		for k, v in pairs(where) do
			table.insert(w, self:processPlaceholders(unpack(v)))
		end
		for k, v in pairs(orWhere) do
			table.insert(ow, self:processPlaceholders(unpack(v)))
		end
		res = table.join(w, ") AND (")
		if res ~= "" then
			res = " WHERE ("..res..")"
		end
		res2 = table.join(ow, ") OR (")
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
				table.insert(res, "RAND()")
			elseif string.beginsWith(v, "-") then
				table.insert(res, self:processPlaceholder("?#", string.slice(v, 2)).." DESC")
			else
				table.insert(res, self:processPlaceholder("?#", v).." ASC")
			end
		end
		res = table.join(res, ", ")
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
		return " SET "..table.join(res, ", ")
	end,
	constructValues = function (self, placeholders, values)
		local res, _, v = {}
		for _, v in pairs(values) do
			table.insert(res, self:processPlaceholders(placeholders, unpack(v)))
		end
		return "("..table.join(res, "), (")..")"
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
			table.insert(res, fld)
		end
		return table.join(res, ", ")
	end,
	constructPrimaryKey = function (self, primary)
		local res, _, v = {}
		if not primary then return "" end
		for _, v in pairs(primary) do
			table.insert(res, self:processPlaceholder("?#", v))
		end
		return ", PRIMARY KEY ("..table.join(res, ", ")..")"
	end,
	constructUnique = function (self, unique)
		local res, _, v, uniq, v2 = {}
		if not unique then return "" end
		for _, v in pairs(unique) do
			uniq = {}
			for _, v2 in pairs(v) do
				table.insert(uniq, self:processPlaceholder("?#", v2))
			end
			table.insert(res, ", UNIQUE ("..table.join(uniq, ", ")..")")
		end
		return table.join(res, ",")
	end,
	constructConstraints = function (self, refs)
		local _, v, res, ref = nil, nil, {}
		if not refs then return "" end
		for _, v in pairs(refs) do
			ref = self:processPlaceholders(", CONSTRAINT FOREIGN KEY (?#) REFERENCES ?# (?#)", v[1], v[2], v[3])
			if v[4] then ref = ref.." ON UPDATE "..v[4] end
			if v[5] then ref = ref.." ON DELETE "..v[5] end
			table.insert(res, ref)
		end
		return table.join(res)
	end,
	constructOptions = function (self, options)
		local res, k, v = {}
		if not options then return "" end
		for k, v in pairs(options) do
			if k == "charset" then
				table.insert(res, "CHARACTER SET "..v)
			elseif k == "engine" then
				table.insert(res, "ENGINE = "..v)
			else
				Exception("Unsupported option "..k.."!"):throw()
			end
		end
		return " "..table.join(res, " ")
	end,
	constructJoins = function (self, joins)
		local res, k, v, tbl = {}
		for k, v in pairs(joins.inner) do
			if "table" == type(v[1]) then
				local name, tbl = next(v[1])
				table.insert(res, self:processPlaceholders("JOIN ?# AS ?# ON "..v[2], tbl, name))
			else
				table.insert(res, self:processPlaceholders("JOIN ?# ON "..v[2], v[1]))
			end
		end
		res = table.join(res, " ")
		if "" ~= res then
			return " "..res
		else
			return ""
		end
	end
}

return {
	Driver = MysqlDriver
}
