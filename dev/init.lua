local table = require "luv.table"
local string = require "luv.string"
local type, rawget, io, tostring, pairs, getmetatable = type, rawget, io, tostring, pairs, getmetatable
local require, os, debug = require, os, debug
local Object = require "luv.oop".Object

module(...)

local function dump (obj, depth, tab, seen)
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
		res = res..string.format("%q", obj)
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
		if table.ifind(seen, obj) then
			res = res.."[RECURSION]"
		elseif 0 ~= depth then
			table.insert(seen, obj)
			res = res.."{\n"
			local ntab = tab.."  "
			for key, val in pairs(obj) do
				if key ~= "__tag" then
					res = res..ntab..key.." = "..dump(val, depth-1, ntab, seen)..";\n"
				end
			end
			if getmetatable(obj) then
				res = res..ntab.."__metatable = "..dump(getmetatable(obj), depth-1, ntab, seen).."\n"
			end
			res = res..tab.."}"
			table.iremoveValue(seen, obj)
		end
	elseif type(obj) == "function" then
		local info = debug.getinfo(obj)
		res = res.."[function "..info.short_src..":"..info.linedefined.."]"
	else
		res = res..type(obj)
	end
	return res
end

local function dprint (...) io.write(dump(...)) end

local Profiler = Object:extend{
	__tag = .....".Profiler";
	init = function (self) self.stat = {} end;
	beginSection = function (self, section)
		self.stat[section] = self.stat[section] or {}
		local statSection = self.stat[section]
		statSection.begin = os.clock()
	end;
	endSection = function (self, section)
		local statSection = self.stat[section] or Exception "begin section first"
		statSection.total = (statSection.total or 0) + (os.clock()-statSection.begin)
		statSection.count = (statSection.count or 0) + 1
	end;
	getStat = function (self) return self.stat end;
}

return {dump=dump;dprint=dprint;Profiler=Profiler}
