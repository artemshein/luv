local string = require"luv.string"
local table, require = table, require
local io, ipairs, type, error, debug = io, ipairs, type, error, debug
local unpack, pairs, math = unpack, pairs, math
local Object = require"luv.oop".Object
local html = require"luv.utils.html"
local Exception = require"luv.exceptions".Exception

module(...)

local property = Object.property

local Coverage = Object:extend{
	__tag = .....".Coverage";
	oldHook = property"table";
	counter = property"number";
	sourceFileName = property"string";
	init = function (self)
		self._info = {}
		self:oldHook{debug.gethook()}
		self:counter(0)
		self:sourceFileName(debug.getinfo(1).short_src)
		debug.sethook(function (type, lineNumber)
			local counter = self:counter()
			if counter > 10000000 then
				debug.sethook()
				Exception"recursion"
			end
			self:counter(counter+1)
			if type ~= "line" then
				return
			end
			local hook = {debug.gethook()}
			debug.sethook()
			local info = debug.getinfo(2)
			local fileName = info.short_src
			self._info[fileName] = self._info[fileName] or {}
			local activelines = debug.getinfo(2, "L").activelines
			for _, line in ipairs(activelines) do
				self._info[fileName][line] = self._info[fileName][line] or false
			end
			if "Lua" == info.what and self:sourceFileName() ~= info.short_src then
				self._info[fileName][lineNumber] = true
			end
			debug.sethook(unpack(hook))
		end, "l")
	end;
	_end = function (self)
		debug.sethook(unpack(self:oldHook() or {}))
		self:oldHook{}
	end;
	info = function (self, only, exclude)
		if self._coveredInfo then
			return self._coveredInfo
		end
		self:_end()
		self._parsedInfo = {}
		self._coverInfo = {}
		for source, info in pairs(self._info) do
			local skipFlag = false
			if only then
				for i, v in ipairs(only) do
					if not string.find(source, v) then
						skipFlag = true
					end
				end
			end
			if exclude then
				for i, v in ipairs(exclude) do
					if string.find(source, v) then
						skipFlag = true
					end
				end
			end
			if not skipFlag then
				self._parsedInfo[source] = self:_parseScript(source)
				local covered, notCovered, coveredEmpty = {}, {}, {}
				for line, parsedInfo in pairs(self._parsedInfo[source]) do
					if not info[line] then
						notCovered[line] = parsedInfo
					else
						covered[line] = parsedInfo
					end
				end
				for line, coverInfo in pairs(info) do
					if not self._parsedInfo[source][line] then
						coveredEmpty[line] = coverInfo
					end
				end
				self._coverInfo[source] = {covered=covered;notCovered=notCovered;coveredEmpty=coveredEmpty;coverPercentage=math.floor(table.size(info)/table.size(self._parsedInfo[source])*100)}
			end
		end
		return self._coverInfo
	end;
	asHtmlTable = function (self, ...)
		self:_end()
		local coverInfo = self._info
		require"luv.dev".dprint(coverInfo, 2)
		--[[local res = '<table class="coverage"><thead><tr><td>Source</td><td>Coverage (&plusmn;10%)</td></tr></thead><tbody>'
		for source, info in pairs(coverInfo) do
			--local min, max = math.max(info.coverPercentage-5, 0), math.min(info.coverPercentage+5, 100)
			res = res.."<tr><td>"..html.escape(source).."</td><td>"..(info.coverPercentage or "-").."%</td></tr>"
		end
		return res.."</tbody></table>"]]
	end;
	sourceAsHtml = function (self, source)
		local lineNumber = 1
		local info = self:info()[source]
		local res = '<pre class="coverage">'
		for line in io.lines(source) do
			if info.covered and info.covered[lineNumber] then
				res = res..'<span class="covered">'..html.escape(line).."</span><br />"
			elseif info.notCovered and info.notCovered[lineNumber] then
				res = res..'<span class="notCovered">'..html.escape(line).."</span><br />"
			elseif info.coveredEmpty and info.coveredEmpty[lineNumber] then
				res = res..'<span class="coveredEmpty">'..html.escape(line).."</span><br />"
			else
				res = res..'<span class="empty">'..html.escape(line).."</span><br />"
			end
			lineNumber = lineNumber + 1
		end
		return res.."</pre>"
	end;
}

return {Coverage=Coverage}
