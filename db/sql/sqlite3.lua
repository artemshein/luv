local require = require
local string = require"luv.string"
local table = require"luv.table"
local io, tostring, tonumber, pairs, ipairs, type, getmetatable, unpack, next = io, tostring, tonumber, pairs, ipairs, type, getmetatable, unpack, next
local Driver, LuaSql = require"luv.db.sql".Driver, require"luasql.sqlite3"

module(...)

local Select = Driver.Select:extend{
	__tag = .....".Select";
	__tostring = function (self)
		return
			"SELECT "
			..self._db:constructFields(self._fields, self._tables)
			..self._db:constructFrom(self._tables)
			..self._db:constructJoins(self._joins)
			..self._db:constructWhere(self._conditions.where, self._conditions.orWhere)
			..self._db:constructOrder(self._conditions.order)
			..self._db:constructLimit(self._conditions.limit)
			..";"
	end;
}

local SelectRow = Driver.SelectRow:extend{
	__tag = .....".SelectRow";
	__tostring = Select.__tostring;
}

local SelectCell = Driver.SelectCell:extend{
	__tag = .....".SelectCell";
	__tostring = SelectRow.__tostring;
}

local Insert = Driver.Insert:extend{
	__tag = .....".Insert";
	__tostring = function (self)
		return
			"INSERT INTO "
			..self._db:processPlaceholder("?#", self._table)
			.." ("..self._db:constructFields(self._fieldNames)..") VALUES "
			..self._db:constructValues(self._fields, self._valuesData)
			..";"
	end;
}

local InsertRow = Driver.InsertRow:extend{
	__tag = .....".InsertRow";
	__tostring = function (self)
		return
			"INSERT INTO "
			..self._db:processPlaceholder("?#", self._table)
			..self._db:constructSet(self._sets)
			..";"
	end;
} 

local Update = Driver.Update:extend{
	__tag = .....".Update";
	__tostring = function (self)
		return
			"UPDATE "
			..self._db:processPlaceholder("?#", self._table)
			..self._db:constructSet(self._sets)
			..self._db:constructWhere(self._conditions.where, self._conditions.orWhere)
			..self._db:constructOrder(self._conditions.order)
			..self._db:constructLimit(self._conditions.limit)
			..";"
	end;
}

local UpdateRow = Driver.UpdateRow:extend{
	__tag = .....".UpdateRow";
	__tostring = Update.__tostring;
}

local Delete = Driver.Delete:extend{
	__tag = .....".Delete";
	__tostring = function (self)
		return
			"DELETE FROM "
			..self._db:processPlaceholder("?#", self._table)
			..self._db:constructWhere(self._conditions.where, self._conditions.orWhere)
			..self._db:constructOrder(self._conditions.order)
			..self._db:constructLimit(self._conditions.limit)
			..";"
	end;
}

local DeleteRow = Driver.DeleteRow:extend{
	__tag = .....".DeleteRow";
	__tostring = Delete.__tostring;
}

local CreateTable = Driver.CreateTable:extend{
	__tag = .....".CreateTable";
	init = function (self, ...)
		Driver.CreateTable.init(self, ...)
		self._options = {charset="utf8", engine="InnoDB"}
	end;
	__tostring = function (self)
		return
			"CREATE TABLE "
			..self._db:processPlaceholder("?#", self._table)
			.." ("
			..self._db:constructFieldsDefinition(self._fields)
			..self._db:constructPrimaryKey(self._primaryKeyValue)
			..self._db:constructUnique(self._unique)
			..self._db:constructConstraints(self._constraints)
			..")"
			..self._db:constructOptions(self._options)
			..";"
	end;
}

local DropTable = Driver.DropTable:extend{
	__tag = .....".DropTable";
	__tostring = function (self)
		return self._db:processPlaceholders("DROP TABLE ?#;", self._table)
	end;
}

local AddColumn = Driver.AddColumn:extend{
	__tag = .....".AddColumn";
	__tostring = function (self)
		local db = self:db()
		return
			"ALTER TABLE "
			..db:processPlaceholder("?#", self._table)
			.." ADD "
			..db:constructFieldsDefinition{self._column}
			..";"
	end;
}

local RemoveColumn = Driver.RemoveColumn:extend{
	__tag = .....".RemoveColumn";
	__tostring = function (self)
		local db = self:db()
		return
			"ALTER TABLE "
			..db:processPlaceholder("?#", self._table)
			.." DROP "
			..db:processPlaceholder("?#", self._column)
			..";"
	end;
}

local Sqlite3Driver = Driver:extend{
	__tag = .....".Driver";
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
	init = function (self, host, login, pass, database, port, params)
		local sqlite = LuaSql.sqlite3()
		self._connection, error = sqlite:connect(database, login, pass, host, port)
		if not self._connection then
			Driver.Exception("Could not connect to "..login.."@"..host.." (using password: "..(pass and "yes" or "no").."): "..error)
		end
	end;
	lastInsertId = function (self)
		local res = self:query("SELECT LAST_INSERT_ROWID() AS `i`;")
		if not res then
			return nil
		end
		return tonumber(res.i)
	end;
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
			if not num then Driver.Exception"Not a valid number given!" end
			return tostring(num)
		elseif placeholder == "?#" then
			if type(value) == "table" then
				local res = ""
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
			local res = ""
			for _, v in ipairs(value) do
				if res ~= "" then res = res..", " end
				if type(v) == "number" then
					res = res..self:processPlaceholder("?d", v)
				elseif type(v) == "string" then
					res = res..self:processPlaceholder("?", v)
				else
					Driver.Exception("invalid value type "..type(v))
				end
			end
			return res
		elseif placeholder == "?v" then
			local res = ""
			for k, v in pairs(value) do
				if res ~= "" then res = res..", " end
				res = res..self:processPlaceholder("?#", k)
				if type(v) == "number" then
					res = res.."="..self:processPlaceholder("?d", v)
				elseif type(v) == "string" then
					res = res.."="..self:processPlaceholder("?", v)
				else
					Driver.Exception"Invalid value type!"
				end
			end
			return res
		end
		Driver.Exception("Invalid placeholder "..string.format("%q", placeholder).."!")
	end;
	constructFields = function (self, fields, tables)
		local res = {}
		for k, v in pairs(fields) do
			if type(k) == "string" then
				res[k] = self:processPlaceholder("?#", v).." AS "..self:processPlaceholder("?#", k)
			else
				if "*" == v then
					res[k] = v
				else
					res[k] = self:processPlaceholder("?#", v)
				end
			end
		end
		res = table.join(res, ", ")
		if res == "" or res == "*" then return self:processPlaceholder("?#", tables[1])..".*" end
		return res
	end;
	constructFrom = function (self, from)
		local res = {}
		for k, v in pairs(from) do
			if type(k) == "string" then
				res[k] = self:processPlaceholder("?#", v).." AS "..self:processPlaceholder("?#", k)
			else
				res[k] = self:processPlaceholder("?#", v)
			end
		end
		return " FROM "..table.join(res, ", ")
	end;
	constructWhere = function (self, where, orWhere)
		local w, ow, res, res2 = {}, {}, nil, nil
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
	end;
	constructOrder = function (self, order)
		local res = {}
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
	end;
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
	end;
	constructSet = function (self, sets)
		local namesIndex, valuesIndex = 1, 1
		local names, values, namesVals, valuesVals = {}, {}, {}, {}, {}
		for _, set in ipairs(sets) do
			local exprs = set[1]:explode","
			for _, expr in ipairs(exprs) do
				local name, value = expr:split"="
				table.insert(names, name)
				table.insert(values, value)
			end
			for i = 2, #set do
				if i == 2 then
					namesVals[namesIndex] = set[i]
					namesIndex = namesIndex + 1
				else
					valuesVals[valuesIndex] = set[i]
					valuesIndex = valuesIndex + 1
				end
			end
			if namesIndex > valuesIndex then
				valuesIndex = valuesIndex + 1
			end
		end
		local vals = {}
		for i = 1, #namesVals do
			vals[i] = namesVals[i]
		end
		local j = #vals
		for i = 1, #valuesVals do
			vals[j+i] = valuesVals[i]
		end
		return self:processPlaceholders(" ("..table.join(names, ", ")..") VALUES ("..table.join(values, ", ")..")", unpack(vals))
	end;
	constructValues = function (self, placeholders, values)
		local res = {}
		for _, v in pairs(values) do
			table.insert(res, self:processPlaceholders(placeholders, unpack(v)))
		end
		return "("..table.join(res, "), (")..")"
	end;
	constructFieldsDefinition = function (self, fields)
		local res, fld = {}
		for _, v in pairs(fields) do
			fld = self:processPlaceholder("?#", v[1]).." "..v[2]
			local options = v[3] or {}
			if options.primaryKey then fld = fld.." PRIMARY KEY" end
			if options.serial then fld = fld.." AUTOINCREMENT" end
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
					Driver.Exception("Unsupported default option type \""..type(options.default).."\"!")
				end
			end
			table.insert(res, fld)
		end
		return table.join(res, ", ")
	end;
	constructPrimaryKey = function (self, primary)
		local res = {}
		if not primary then return "" end
		for _, v in pairs(primary) do
			table.insert(res, self:processPlaceholder("?#", v))
		end
		return ", PRIMARY KEY ("..table.join(res, ", ")..")"
	end;
	constructUnique = function (self, unique)
		local res, uniq, v2 = {}
		if not unique then return "" end
		for _, v in pairs(unique) do
			uniq = {}
			for _, v2 in pairs(v) do
				table.insert(uniq, self:processPlaceholder("?#", v2))
			end
			table.insert(res, ", UNIQUE ("..table.join(uniq, ", ")..")")
		end
		return table.join(res, ",")
	end;
	constructConstraints = function (self, refs)
		local res, ref = {}
		if not refs then return "" end
		for _, v in pairs(refs) do
			ref = self:processPlaceholders(", CONSTRAINT FOREIGN KEY (?#) REFERENCES ?# (?#)", v[1], v[2], v[3])
			if v[4] then ref = ref.." ON UPDATE "..v[4] end
			if v[5] then ref = ref.." ON DELETE "..v[5] end
			table.insert(res, ref)
		end
		return table.join(res)
	end;
	constructOptions = function (self, options)
		return ""
	end;
	constructJoins = function (self, joins)
		local res, tbl = {}
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
	end;
}

return {Driver=Sqlite3Driver}
