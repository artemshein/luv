require "luv.string"
require "luv.table"
local type, pairs, table, string, tostring = type, pairs, table, string, tostring

module(...)

local function to (self, seen)
	local seen = seen or {}
	if "boolean" == type(self) then
		return self and "true" or "false"
	elseif "string" == type(self) then
		return "\""..string.escape(self).."\""
	elseif "number" == type(self) then
		return tostring(self)
	elseif "table" == type(self) then
		table.insert(seen, self)
		local res, first, k, v = "{", true
		for k, v in pairs(self) do
			local vType = type(v)
			if "function" ~= vType and "userdata" ~= vType then
				if first then
					first = false
				else
					res = res..","
				end
				if ("table" == vType and not table.find(seen, v)) or "table" ~= vType then
					if "string" == type(k) then
						res = res.."\""..string.escape(k).."\":"..to(v, seen)
					else
						res = res..k..":"..to(v, seen)
					end
				end
			end
		end
		table.removeValue(seen, self)
		return res.."}"
	else
		return "null"
	end
end

return {to=to}
