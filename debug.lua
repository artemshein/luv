require"luv.table"
local debug, table, type, io, rawget, tostring, pairs, getmetatable = debug, table, type, io, rawget, tostring, pairs, getmetatable

module(...)

debug.dump = function (obj, depth, tab, seen)
	local tab = tab or ""
	local depth = depth or 10
	local seen = seen or {}
	if type(obj) == "nil" then
		io.write"nil"
	elseif obj == true then
		io.write"true"
	elseif obj == false then
		io.write"false"
	elseif type(obj) == "number" then
		io.write(obj)
	elseif type(obj) == "string" then
		io.write("\"", obj, "\"")
	elseif type(obj) == "table" then
		local tag = rawget(obj, "__tag")
		if tag then
			io.write(tag)
		else
			io.write(tostring(obj))
		end
		if table.find(seen, obj) then
			io.write" RECURSION"
		elseif 0 ~= depth then
			table.insert(seen, obj)
			io.write"{\n"
			local ntab = tab.."  "
			for key, val in pairs(obj) do
				if key ~= "__tag" then
					io.write(ntab, key, " = ")
					debug.dump(val, depth-1, ntab, seen)
					io.write",\n"
				end
			end
			if getmetatable(obj) then
				io.write(ntab, "__metatable = ")
				debug.dump(getmetatable(obj), depth-1, ntab, seen)
				io.write"\n"
			end
			io.write(tab, "}")
			table.removeValue(seen, obj)
		end
	elseif type(obj) == "function" then
		io.write(tostring(obj))
	else
		io.write(type(obj))
	end
end

return debug
