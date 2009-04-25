require"luv.table"
local debug, table, type, rawget, io, tostring, pairs, getmetatable = debug, table, type, rawget, io, tostring, pairs, getmetatable

module(...)

debug.dump = function (obj, depth, tab, seen)
	local res, tab = "", tab or ""
	local depth = depth or 1
	local seen = seen or {}
	if type(obj) == "nil" then
		res = res.."nil"
	elseif obj == true then
		res = res.."true"
	elseif obj == false then
		res = res.."false"
	elseif type(obj) == "number" then
		res = res..obj
	elseif type(obj) == "string" then
		res = res.."\""..obj.."\""
	elseif type(obj) == "table" then
		local tag = rawget(obj, "__tag")
		if tag then
			res = res..tag
		else
			local mt = getmetatable(obj)
			if not mt or not mt.__tostring then
				res = res..tostring(obj)
			else
				res = res.."table"
			end
		end
		if table.find(seen, obj) then
			res = res.."[RECURSION]"
		elseif 0 ~= depth then
			table.insert(seen, obj)
			res = res.."{\n"
			local ntab = tab.."  "
			for key, val in pairs(obj) do
				if key ~= "__tag" then
					res = res..ntab..key.." = "..debug.dump(val, depth-1, ntab, seen)..",\n"
				end
			end
			if getmetatable(obj) then
				res = res..ntab.."__metatable = "..debug.dump(getmetatable(obj), depth-1, ntab, seen).."\n"
			end
			res = res..tab.."}"
			table.removeValue(seen, obj)
		end
	elseif type(obj) == "function" then
		res = res..tostring(obj)
	else
		res = res..type(obj)
	end
	return res
end

debug.dprint = function (...) io.write(debug.dump(...)) end

return debug
