local string = require"luv.string"
local table, require, tostring = table, require, tostring
local io, ipairs, type, error, debug = io, ipairs, type, error, debug
local unpack, pairs, math = unpack, pairs, math
local Object = require"luv.oop".Object
local html = require"luv.utils.html"
local Exception = require"luv.exceptions".Exception
local crypt = require"luv.crypt"

module(...)

local property = Object.property

local Coverage = Object:extend{
	__tag = .....".Coverage";
	oldHook = property"table";
	sourceFileName = property"string";
	info = property"table";
	init = function (self)
		self:info{}
		self:oldHook{debug.gethook()}
		self:sourceFileName(debug.getinfo(1).short_src)
		debug.sethook(function (type, lineNumber)
			local hook = {debug.gethook()}
			debug.sethook()
			local funcInfo = debug.getinfo(2)
			local fileName = funcInfo.short_src
			local info = self:info()
			if not fileName:beginsWith"[" then
				info[fileName] = info[fileName] or {}
				local activelines = debug.getinfo(2, "L").activelines
				for line in pairs(activelines) do
					info[fileName][line] = info[fileName][line] or false
				end
				if "Lua" == funcInfo.what and self:sourceFileName() ~= fileName then
					info[fileName][lineNumber] = true
				end
			end
			debug.sethook(unpack(hook))
		end, "l")
	end;
	_end = function (self)
		debug.sethook(unpack(self:oldHook() or {}))
		self:oldHook{}
	end;
	asHtmlTable = function (self, ...)
		self:_end()
		local info = self._info
		local res = '<table class="coverage"><thead><tr><td>Source</td><td>Coverage</td></tr></thead><tbody>'
		for fileName, info in pairs(info) do
			local totalLines, coveredLines = 0, 0
			for line, value in pairs(info) do
				totalLines = totalLines + 1
				if value then coveredLines = coveredLines + 1 end
			end
			res = res.."<tr><td>"..html.escape(fileName).."</td><td>"..(math.ceil(coveredLines/totalLines*100)).."%</td></tr>"
		end
		return res.."</tbody></table>"
	end;
	sourceAsHtml = function (self, source)
		self:_end()
		local lineNumber = 1
		local info = self._info[source]
		local res = '<pre class="coverage">'
		for line in io.lines(source) do
			local covered = info[lineNumber]
			if covered then
				res = res..'<span class="covered">'..html.escape(line).."</span><br />"
			elseif false == covered then
				res = res..'<span class="notCovered">'..html.escape(line).."</span><br />"
			else
				res = res..'<span class="empty">'..html.escape(line).."</span><br />"
			end
			lineNumber = lineNumber + 1
		end
		return res.."</pre>"
	end;
	fullInfoAsHtml = function (self)
		self:_end()
		local info = self._info
		local res = '<table class="coverage"><thead><tr><td>Source</td><td>Coverage</td></tr></thead><tbody>'
		for fileName, info in pairs(info) do
			local totalLines, coveredLines = 0, 0
			for line, value in pairs(info) do
				totalLines = totalLines + 1
				if value then coveredLines = coveredLines + 1 end
			end
			res = res..'<tr><td><a href="#'..tostring(crypt.Md5(fileName))..'">'..html.escape(fileName).."</a></td><td>"..(math.ceil(coveredLines/totalLines*100)).."%</td></tr>"
		end
		res = res.."</tbody></table>"
		for fileName, info in pairs(info) do
			res = res..'<a name="'..tostring(crypt.Md5(fileName))..'" /><h2>'..fileName.."</h2>"..self:sourceAsHtml(fileName)
		end
		return res
	end;
}

return {Coverage=Coverage}
