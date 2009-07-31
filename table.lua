local table, pairs, next, type, require, ipairs = table, pairs, next, type, require, ipairs
local tostring, debug, error = tostring, debug, error

module(...)

table.keys = function (self)
	local res = {}
	for key, _ in pairs(self) do
		table.insert(res, key)
	end
	return res
end

table.map = function (self, func)
	local res = {}
	for key, val in pairs(self) do
		res[key] = func(val)
	end
	return res
end

table.imap = function (self, func)
	local res = {}
	for _, val in ipairs(self) do
		local newVal = func(val)
		if newVal then
			table.insert(res, func(val))
		end
	end
	return res
end

table.ifind = function (self, val)
	if "table" ~= type(self) then
		error ("table expected "..debug.traceback())
	end
	for k, v in ipairs(self) do
		if val == v then
			return k
		end
	end
end

table.find = function (self, val)
	for k, v in pairs(self) do
		if val == v then
			return k
		end
	end
end

table.iremoveValue = function (self, val)
	local key = table.ifind(self, val)
	if key then
		return table.remove(self, key)
	end
end

table.removeValue = function (self, val)
	local key = table.find(self, val)
	if key then
		return table.remove(self, key)
	end
end

table.copy = function (self)
	local res = {}
	for k, v in pairs(self) do
		res[k] = v
	end
	return res
end

table.deepCopy = function (tbl, seen)
	local res = {}
	seen = seen or {}
	seen[tbl] = res
	for k, v in pairs(tbl) do
		if 'table' == type(v) then
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
end

table.join = function (tbl, sep)
	local res
	sep = sep or ""
	for _, v in pairs(tbl) do
		res = (res and res..sep or "")..tostring(v)
	end
	return res or ""
end

table.ijoin = function (self, sep)
	local res
	sep = sep or ""
	for _, v in ipairs(self) do
		res = (res and res..sep or "")..tostring(v)
	end
	return res or ""
end

table.size = function (tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

table.empty = function (self)
	return nil == next(self)
end

return table
