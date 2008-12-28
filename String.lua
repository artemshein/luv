local Debug = require"Debug"
local string, table, unpack, select = string, table, unpack, select

module(...)

string.slice = string.sub

string.capitalize = function (self)
	return string.upper(string.slice(self, 1, 1))..string.slice(self, 2)
end

string.beginsWith = function (str, beg)
	if 1 ~= string.find(str, beg, 1, true) then
		return false
	end
	return true
end

string.split = function (str, ...)
	local res, tail, i, len = {}, str, 1, select("#", ...)
	for i = 1, len do
		if not tail then break end
		local begPos, endPos = string.find(tail, select(i, ...), 1, true)
		if begPos then
			table.insert(res, string.slice(tail, 1, begPos-1))
			tail = string.slice(tail, endPos+1)
		end
	end
	table.insert(res, tail)
	return unpack(res)
end

string.explode = function (self, ex)
	local res, tail, begPos, endPos = {}, self
	begPos, endPos = string.find(tail, ex, 1, true)
	while begPos do
		table.insert(res, string.slice(tail, 1, begPos-1))
		tail = string.slice(tail, endPos+1)
		begPos, endPos = string.find(tail, ex, 1, true)
	end
	table.insert(res, tail)
	return res
end

string.htmlEscape = function (str)
	return string.gsub(str, "[\\\"]", {["\""] = "&quot;"})
end

return string