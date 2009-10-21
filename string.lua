require"luv.utf8data"
require"luv.utf8"
local table = require"luv.table"
local require, getmetatable = require, getmetatable
local string, table, unpack, select, debug, error, loadstring, assert = string, table, unpack, select, debug, error, loadstring, assert
local type, tostring, pairs, io, error = type, tostring, pairs, io, error
local checkTypes = require"luv.checktypes".checkTypes

module(...)

string.slice = string.utf8sub
string.upper = string.utf8upper
string.lower = string.utf8lower
string.replace = string.gsub

-- Interpolate (Python style)
getmetatable("").__mod = function (self, tab)
	return (self:gsub("%%%((%a%w*)%)([-0-9%.]*[cdeEfgGiouxXsq])",
		function(k, fmt)
			return tab[k] and ("%"..fmt):format(tab[k]) or "%("..k..")"..fmt
		end
	))
end

string.capitalize = checkTypes("string", function (self)
	if #self == 0 then return self end
	return self:slice(1, 1):upper()..self:slice(2)
end, "string")

string.beginsWith = checkTypes("string", "string", function (self, beg)
	if 1 ~= self:find(beg, 1, true) then
		return false
	end
	return true
end, "boolean")

string.endsWith = checkTypes("string", "string", function (self, search)
	if self:slice(-string.utf8len(search)) ~= search then
		return false
	end
	return true
end, "boolean")

string.split = checkTypes("string", function (str, ...)
	local res, tail, values = {}, str, {select(1, ...)}
	for i = 1, select("#", ...) do
		if not tail then break end
		local begPos, endPos = tail:find(values[i], 1, true)
		if begPos then
			table.insert(res, tail:sub(1, begPos-1))
			tail = tail:sub(endPos+1)
		end
	end
	table.insert(res, tail)
	return unpack(res)
end)

string.findLast = checkTypes("string", function (self, substr)
	local i, lastBegPos, lastEndPos = 1
	local begPos, endPos = self:find(substr, i, true)
	while begPos do
		lastBegPos = begPos
		lastEndPos = endPos
		i = begPos+1
		begPos, endPos = self:find(substr, i, true)
	end
	return lastBegPos, lastEndPos
end)

string.explode = checkTypes("string", "string", function (self, ex)
	local res, tail, begPos, endPos = {}, self
	begPos, endPos = tail:find(ex, 1, true)
	while begPos do
		table.insert(res, tail:sub(1, begPos-1))
		tail = tail:sub(endPos+1)
		begPos, endPos = tail:find(ex, 1, true)
	end
	table.insert(res, tail)
	return res
end, "table")

local trimChars = {(" "):byte();("\t"):byte();("\v"):byte();("\r"):byte();("\n"):byte();0}

string.ltrim = checkTypes("string", function (self)
	local index = 1
	for i = 1, #self do
		if not table.ifind(trimChars, self:byte(i)) then
			index = i
			break
		end
	end
	return self:sub(index)
end, "string")

string.rtrim = checkTypes("string", function (self)
	local index = 1
	for i = #self, 1, -1 do
		if not table.ifind(trimChars, self:byte(i)) then
			index = i
			break
		end
	end
	return self:sub(1, index)
end, "string")

string.trim = checkTypes("string", function (self)
	return self:ltrim():rtrim()
end, "string")

string.serialize = function (self, seen)
	seen = seen or {}
	local selfType = type(self)
	if "string" == selfType then
		return ("%q"):format(self)
	elseif "number" == selfType or "boolean" == selfType or "nil" == selfType  then
		return tostring(self)
	elseif "table" == selfType then
		local res, first = "{", true
		table.insert(seen, self)
		local index = 1
		for k, v in pairs(self) do
			if not table.ifind(seen, v)
			and nil ~= v and "function" ~= type(v) then
				if first then
					first = false
				else
					res = res..";"
				end
				if k == index then
					res = res..string.serialize(v, seen)
					index = index + 1
				else
					if "number" == type(k) then
						res = res.."["..k.."]="
					else
						res = res.."["..("%q"):format(k).."]="
					end
					res = res..string.serialize(v, seen)
				end
			end
		end
		table.iremoveValue(seen, self)
		return res.."}"
	end
	return "nil"
end

string.unserialize = checkTypes("string", function (self)
	if not self then
		return nil
	end
	local func = loadstring("return "..self)
	if not func then
		error("unserialize fails "..debug.traceback().." "..self)
	end
	return func()
end)

return string
