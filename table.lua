local table, pairs, next, type, require, ipairs = table, pairs, next, type, require, ipairs
local tostring, debug, error, setmetatable = tostring, debug, error, setmetatable
local checkTypes = require"luv.checktypes".checkTypes

module(...)

table.keys = checkTypes("table", function (self)
	local res = {}
	for key, _ in pairs(self) do
		table.insert(res, key)
	end
	return res
end, "table")

table.map = checkTypes("table", function (self, func)
	local res = {}
	for key, val in pairs(self) do
		if "string" == type(func) then
			res[key] = val[func](val)
		else
			res[key] = func(val)
		end
	end
	return res
end, "table")

table.imap = checkTypes("table", function (self, func)
	local res = {}
	for _, val in ipairs(self) do
		local newVal
		if "string" == type(func) then
			newVal = val[func](val)
		else
			newVal = func(val)
		end
		if newVal then
			table.insert(res, func(val))
		end
	end
	return res
end, "table")

table.ifind = checkTypes("table", function (self, val)
	for k, v in ipairs(self) do
		if val == v then
			return k
		end
	end
end)

table.find = checkTypes("table", function (self, val)
	for k, v in pairs(self) do
		if val == v then
			return k
		end
	end
end)

table.iremoveValue = checkTypes("table", function (self, val)
	local key = table.ifind(self, val)
	if key then
		return table.remove(self, key)
	end
end)

table.removeValue = checkTypes("table", function (self, val)
	local key = table.find(self, val)
	if key then
		return table.remove(self, key)
	end
end)

table.copy = checkTypes("table", function (self)
	local res = {}
	for k, v in pairs(self) do
		res[k] = v
	end
	return res
end, "table")

table.deepCopy = checkTypes("table", function (tbl, seen)
	local res = {}
	seen = seen or {}
	seen[tbl] = res
	for k, v in pairs(tbl) do
		if "table" == type(v) then
			if seen[v] then
				res[k] = seen[v]
			else
				res[k] = table.deepCopy(v, seen)
			end
		else
			res[k] = v
		end
	end
	seen[tbl] = nil
	return res
end, "table")

table.join = checkTypes("table", function (tbl, sep)
	local res
	sep = sep or ""
	for _, v in pairs(tbl) do
		res = (res and res..sep or "")..tostring(v)
	end
	return res or ""
end, "string")

table.ijoin = checkTypes("table", function (self, sep)
	local res
	sep = sep or ""
	for _, v in ipairs(self) do
		res = (res and res..sep or "")..tostring(v)
	end
	return res or ""
end, "string")

table.size = checkTypes("table", function (tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end, "number")

table.empty = checkTypes("table", function (self)
	return nil == next(self)
end, "boolean")

return table
