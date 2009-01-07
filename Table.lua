local Table = table or {}
local pairs = pairs

module(...)

function Table.find (tbl, val)
	for k, v in pairs(tbl) do
		if val == v then
			return true
		end
	end
	return false
end

function Table.removeValue (tbl, val)
	for k, v in pairs(tbl) do
		if val == v then
			tbl[k] = nil
			return true
		end
	end
	return false
end

function Table.copy (tbl)
	local res, k, v = {}
	for k, v in pairs(tbl) do
		res[k] = v
	end
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
	return Table.size(tbl) == 0
end

return Table
