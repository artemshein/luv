local string = require "luv.string"
local table = table
local io, ipairs, type, error, debug = io, ipairs, type, error, debug
local unpack, pairs, math = unpack, pairs, math
local Object = require "luv.oop".Object
local html = require "luv.utils.html"

module(...)

local Coverage = Object:extend{
	__tag = .....".Coverage";
	init = function (self) self:_begin() end;
	_begin = function (self)
		self._info = {}
		self._oldHook = {debug.gethook()}
		debug.sethook(function (type, lineNumber)
			local hook = {debug.gethook()}
			debug.sethook()
			if type ~= "line" then
				return
			end
			local selfInfo = debug.getinfo(1)
			local info = debug.getinfo(2)
			if not info.short_src:beginsWith"["
			and selfInfo.short_src ~= info.short_src then
				self._info[info.short_src] = self._info[info.short_src] or {}
				self._info[info.short_src][lineNumber] = self._info[info.short_src][lineNumber] or {}
				table.insert(self._info[info.short_src][lineNumber], info)
			end
			debug.sethook(unpack(hook), "l")
		end, "l")
	end;
	_end = function (self)
		debug.sethook(unpack(self._oldHook or {}))
		self._oldHook = nil
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
		local coverInfo = self:info(...)
		local res = '<table class="coverage"><thead><tr><td>Source</td><td>Coverage (&plusmn;10%)</td></tr></thead><tbody>'
		for source, info in pairs(coverInfo) do
			--local min, max = math.max(info.coverPercentage-5, 0), math.min(info.coverPercentage+5, 100)
			res = res.."<tr><td>"..html.escape(source).."</td><td>"..info.coverPercentage.."%</td></tr>"
		end
		return res.."</tbody></table>"
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
	end;--[[
	_parseScript = function (self, filename)
		local skipStatements = {
			"if";"then";"while";"for";"then";"else";"elseif";"local";"do";
			"function";",";";";"="
		}
		local lineNumber, res, skipEnd = 1, {}
		for line in io.lines(filename) do
			local statement = string.ltrim(line)
			if skipEnd then
				local begPos, endPos = string.find(statement, skipEnd)
				if begPos then
					statement = string.ltrim(string.slice(statement, endPos+1))
					skipEnd = nil
				else
					statement = ""
				end
			end
			-- Skip keywords & comments
			local oldLen
			while 0 ~= #statement and oldLen ~= #statement do
				oldLen = #statement
				for _, skip in ipairs(skipStatements) do
					if string.beginsWith(statement, skip) then
						statement = string.ltrim(string.slice(statement, #skip+1))
					end
				end
				if string.beginsWith(statement, "function") then
					local begPos, endPos = string.find(statement, ")", 1, true)
					if begPos then
						statement = string.ltrim(string.slice(statement, endPos+1))
					else
						statement = ""
					end
				--[[elseif string.match(statement, "^%a%w*") then
					local begPos, endPos = string.find(statement, "%a%w*")
					statement = string.ltrim(string.slice(statement, endPos+1))]]
				elseif string.beginsWith(statement, "--[[") then
					local begPos, endPos = string.find(statement, "]]", 5, true)
					if begPos then
						statement = string.ltrim(string.slice(statement, endPos+1))
					else
						skipEnd = "] ]"
						statement = ""
						break
					end
				elseif string.match(statement, "^--%[=*%[") then
					local begPos, endPos = string.find(string.slice(statement, 4), "=*")
					local length = endPos-begPos+1
					local endTerm = "]"..string.rep("=", length).."]"
					begPos, endPos = string.find(statement, endTerm, endPos+2, true)
					if begPos then
						statement = string.ltrim(string.slice(statement, endPos+1))
					else
						skipEnd = endTerm
						statement = ""
						break
					end
				elseif string.beginsWith(statement, "--") then
					statement = ""
					break
				end
			end
			if 0 ~= #statement then
				res[lineNumber] = {line=line;statement=statement}
			end
			lineNumber = lineNumber + 1
		end
		return res
	end]]
}

return {Coverage=Coverage}
