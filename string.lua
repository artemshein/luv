require "luv.utf8data"
require "luv.utf8"
local table = require "luv.table"
local string, table, unpack, select, debug, error, loadstring, assert = string, table, unpack, select, debug, error, loadstring, assert
local type, tostring, pairs, io, error = type, tostring, pairs, io, error

module(...)

string.slice = string.utf8sub

string.capitalize = function (self)
	if not self then
		error("string expected "..debug.traceback())
	end
	if string.len(self) == 0 then return self end
	return string.utf8upper(string.utf8sub(self, 1, 1))..string.utf8sub(self, 2)
end

string.beginsWith = function (str, beg)
	if 1 ~= string.find(str, beg, 1, true) then
		return false
	end
	return true
end

string.endsWith = function (str, search)
	if "string" ~= type(str) or "string" ~= type(search) then
		error("String expected "..debug.traceback())
	end
	if string.sub(str, -string.len(search)) ~= search then
		return false
	end
	return true
end

string.split = function (str, ...)
	local res, tail, values = {}, str, {select(1, ...)}
	for i = 1, select("#", ...) do
		if not tail then break end
		local begPos, endPos = string.find(tail, values[i], 1, true)
		if begPos then
			table.insert(res, string.sub(tail, 1, begPos-1))
			tail = string.sub(tail, endPos+1)
		end
	end
	table.insert(res, tail)
	return unpack(res)
end

string.findLast = function (self, substr)
	local i, lastBegPos, lastEndPos = 1
	local begPos, endPos = string.find(self, substr, i, true)
	while begPos do
		lastBegPos = begPos
		lastEndPos = endPos
		i = begPos+1
		begPos, endPos = string.find(self, substr, i, true)
	end
	return lastBegPos, lastEndPos
end

string.explode = function (self, ex)
	if "string" ~= type(self) then
		error("string expected "..debug.traceback())
	end
	local res, tail, begPos, endPos = {}, self
	begPos, endPos = string.find(tail, ex, 1, true)
	while begPos do
		table.insert(res, string.sub(tail, 1, begPos-1))
		tail = string.sub(tail, endPos+1)
		begPos, endPos = string.find(tail, ex, 1, true)
	end
	table.insert(res, tail)
	return res
end

local trimChars = {string.byte" ";string.byte"\t";string.byte"\v";string.byte"\r";string.byte"\n";0}

string.ltrim = function (self)
	local index = 1
	for i = 1, string.len(self) do
		if not table.ifind(trimChars, string.byte(self, i)) then
			index = i
			break
		end
	end
	return string.sub(self, index)
end

string.rtrim = function (self)
	local index = 1
	for i = string.len(self), 1, -1 do
		if not table.ifind(trimChars, string.byte(self, i)) then
			index = i
			break
		end
	end
	return string.sub(self, 1, index)
end

string.trim = function (self)
	return string.ltrim(string.rtrim(self))
end

--[[
local urlEncodeChars = {36=true;38;43;44;47;58;59;61;63;64}

string.urlEncode = function (self)
	local res, _, byte = ""
	for _, byte in ipairs({string.byte(self, 1, string.len(self))}) do
		if byte > 31 and byte < 127
		res = res..
	end
	return res
end]]

string.replace = string.gsub

string.serialize = function (self, seen)
	seen = seen or {}
	local selfType = type(self)
	if "string" == selfType then
		return string.format("%q", self)
	elseif "number" == selfType or "boolean" == selfType or "nil" == selfType  then
		return tostring(self)
	elseif "table" == selfType then
		local res, first = "{", true
		table.insert(seen, self)
		for k, v in pairs(self) do
			if not table.ifind(seen, v)
			and "function" ~= type(v) and "nil" ~= type(v) then
				if first then
					first = false
				else
					res = res..";"
				end
				res = res.."["..string.serialize(k).."]="..string.serialize(v, seen)
			end
		end
		table.iremoveValue(seen, self)
		return res.."}"
	end
	return ""
end

string.unserialize = function (self)
	if not self then
		return nil
	end
	return assert(loadstring("return "..self))()
end

return string
