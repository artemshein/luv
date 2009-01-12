local Table = table or {}
local pairs, next, type = pairs, next, type

module(...)

Table.find = function (tbl, val)
	for k, v in pairs(tbl) do
		if val == v then
			return true
		end
	end
	return false
end

Table.removeValue = function (tbl, val)
	for k, v in pairs(tbl) do
		if val == v then
			tbl[k] = nil
			return true
		end
	end
	return false
end

Table.copy = function (tbl)
	local res, k, v = {}
	for k, v in pairs(tbl) do
		res[k] = v
	end
	return res
end

Table.deepCopy = function (tbl, seen)
	local res, k, v = {}
	seen = seen or {}
	seen[tbl] = res
	for k, v in pairs(tbl) do
		if "table" == type(v) then
			if seen[v] then
				res[k] = seen[v]
			else
				res[k] = Table.deepCopy(v, seen)
			end
		else
			res[k] = v
		end
	end
	seen[tbl] = nil
	return res
end

Table.join = function (tbl, sp)
	local res, _, v = ""
	sp = sp or ""
	for _, v in pairs(tbl) do
		if res == "" then
			res = v
		else
			res = res..sp..v
		end
	end
	return res
end

Table.size = function (tbl)
	local count, _ = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

Table.isEmpty = function (tbl)
	return nil == next(tbl)
end

return Table
