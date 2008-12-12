local Table = table or {}

module(..., package.seeall)

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

return Table