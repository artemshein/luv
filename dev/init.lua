local table = require "luv.table"
local string = require "luv.string"
local type, rawget, io, tostring, pairs, getmetatable = type, rawget, io, tostring, pairs, getmetatable
local require, os, debug = require, os, debug
local Object = require "luv.oop".Object

module(...)

local function dump (obj, depth, tab, seen)
	local tab = tab or ""
	local depth = depth or 1
	local seen = seen or {}
	if nil == obj then
		return "nil"
	elseif true == obj then
		return "true"
	elseif false == obj then
		return "false"
	elseif "number" == type(obj) then
		return tostring(obj)
	elseif "string" == type(obj) then
		return ("%q"):format(obj)
	elseif "table" == type(obj) then
		local res = ""
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
		if table.ifind(seen, obj) then
			res = res.."[RECURSION]"
		elseif 0 ~= depth then
			table.insert(seen, obj)
			res = res.."{\n"
			local ntab = tab.."  "
			for key, val in pairs(obj) do
				if key ~= "__tag" then
					res = res..ntab..tostring(key).." = "..dump(val, depth-1, ntab, seen)..";\n"
				end
			end
			if getmetatable(obj) then
				res = res..ntab.."__metatable = "..dump(getmetatable(obj), depth-1, ntab, seen).."\n"
			end
			res = res..tab.."}"
			table.iremoveValue(seen, obj)
		end
		return res
	elseif "function" == type(obj) then
		local info = debug.getinfo(obj)
		return "[function "..info.short_src..":"..info.linedefined.."]"
	else
		return type(obj)
	end
end

local function dprint (...) io.write(dump(...)) end

local Profiler = Object:extend{
	__tag = .....".Profiler";
	stat = Object.property"table";
	init = function (self) self:stat{} end;
	beginSection = function (self, section)
		self._stat[section] = self._stat[section] or {}
		local statSection = self._stat[section]
		statSection.begin = os.clock()
	end;
	endSection = function (self, section)
		local statSection = self._stat[section] or Exception "begin section first"
		statSection.total = (statSection.total or 0) + (os.clock()-statSection.begin)
		statSection.count = (statSection.count or 0) + 1
	end;
}

return {dump=dump;dprint=dprint;Profiler=Profiler}
