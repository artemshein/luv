local string = require "luv.string"
local type, table, pairs, io = type, table, pairs, io
local loadstring, setfenv, tostring = loadstring, setfenv, tostring
local Object = require"luv.oop".Object
local fs = require "luv.fs"
local Exception = require "luv.exceptions".Exception
local html = require "luv.utils.html"

module(...)

local Api = Object:extend{
	__tag = .....".Api",
	init = function (self, templatesDirOrDirs)
		if "string" == type(templatesDirOrDirs) then
			self.templatesDirs = {templatesDirOrDirs}
		else
			self.templatesDirs = {}
			if "table" == type(templatesDirOrDirs) then
				for _, v in pairs(templatesDirOrDirs) do
					self:addTemplatesDir(v)
				end
			end
		end
	end;
	addTemplatesDir = function (self, dir)
		table.insert(self.templatesDirs, dir)
	end;
	display = Object.abstractMethod;
	fetch = Object.abstractMethod;
	fetchString = Object.abstractMethod;
	displayString = Object.abstractMethod;
	assign = Object.abstractMethod;
	clear = Object.abstractMethod;
}

local Tamplier = Api:extend{
	__tag = .....".Tamplier",
	init = function (self, ...)
		Api.init(self, ...)
		self.cycleCounters = {}
		self.internal = {
			tostring=tostring;
			includedFiles = {},
			include = function (file, values)
				local oldInternal = self.internal
				if values then
					oldInternal = table.copy(self.internal)
					self:assign(values)
				end
				local includedFiles = self.internal.includedFiles
				if not includedFiles[file] then
					includedFiles[file] = self:getTemplateContents(file)
				end
				local res = self:compileString(includedFiles[file])
				if values then
					self.internal = oldInternal
				end
				return res
			end;
			cycle = function (index, params)
				if not self.cycleCounters[index] then self.cycleCounters[index] = 1 end
				self.cycleCounters[index] = self.cycleCounters[index] + 1
				return params[self.cycleCounters[index] % table.maxn(params) + 1]
			end;
		}
	end;
	assign = function (self, var, value)
		if type(var) == "table" then
			for i, v in pairs(var) do
				self.internal[i] = v
			end
		else
			self.internal[var] = value
		end
	end;
	compileString = function (self, str)
		local res = string.gsub(str, "{{", "]===]..tostring(")
		res = string.gsub(res, "}}", ")..[===[")
		res = string.gsub(res, "{%%", "]===]\n")
		res = "local s = [===["..string.gsub(res, "%%}", "\ns = s..[===[").."]===]\nreturn s"
		local func, err = loadstring(res)
		if not func then
			Exception(err)
		end
		setfenv(func, self.internal)
		return func()
	end;
	fetchString = function (self, str)
		return self:compileString(str)
	end;
	displayString = function (self, str)
		io.write(self:fetchString(str))
	end;
	getTemplateContents = function (self, template)
		if "table" ~= type(self.templatesDirs) or table.isEmpty(self.templatesDirs) then
			local tpl = fs.File(template)
			if tpl:isExists() then
				return tpl:openReadAndClose "*a"
			end
		end
		for _, v in pairs(self.templatesDirs) do
			local tpl = fs.File(v / template)
			if tpl:isExists() then
				return tpl:openReadAndClose "*a"
			end
		end
		Exception("Template "..template.." not found!")
	end;
	fetch = function (self, template)
		return self:compileString(self:getTemplateContents(template))
	end;
	display = function (self, template)
		io.write(self:fetch(template))
	end;
}

local SafeHtml = Object:extend{
	__tag = .....".SafeHtml";
	init = function (self, html)
		self._html = html
	end;
	__tostring = function (self) return tostring(self._html) end;
}

local Tamplier2 = Api:extend{
	__tag = .....".Tamplier2",
	init = function (self, ...)
		Api.init(self, ...)
		self.cycleCounters = {}
		self.internal = {
			tostring = tostring;
			sections = {};
			escape = function (str)
				if "table" == type(str) and str.isKindOf and str:isKindOf(SafeHtml) then
					return str
				else
					return html.escape(str)
				end
			end;
			unsafe = function (str) return SafeHtml(str) end;
			section = function (section)
				if not self.internal.sections[section] then
					Exception("section "..section.." not found")
				end
				return self.internal.sections[section]()
			end;
			includedFiles = {};
			include = function (file, values)
				local oldInternal = self.internal
				if values then
					oldInternal = table.copy(self.internal)
					self:assign(values)
				end
				local includedFiles = self.internal.includedFiles
				if not includedFiles[file] then
					includedFiles[file] = self:getTemplateContents(file)
				end
				local res = self:compileString(includedFiles[file])()
				if values then
					self.internal = oldInternal
				end
				return self.internal.unsafe(res)
			end;
			cycle = function (index, params)
				if not self.cycleCounters[index] then self.cycleCounters[index] = 1 end
				self.cycleCounters[index] = self.cycleCounters[index] + 1
				return params[self.cycleCounters[index] % table.maxn(params) + 1]
			end;
		}
	end;
	assign = function (self, var, value)
		if type(var) == "table" then
			for i, v in pairs(var) do
				self.internal[i] = v
			end
		else
			self.internal[var] = value
		end
	end;
	compileString = function (self, str)
		local function createFunction (code)
			local func, err = loadstring('local s = ""'..code.."; return s")
			if not func then
				Exception(err)
			end
			return func
		end
		local currentSection = "main"
		local res = ""
		local offsetPos = 1
		while true do
			local begPos = string.find(str, "{", offsetPos, true)
			if not begPos then
				res = res.."..[===["..str.."]===]"
				break
			end
			local operand = string.slice(str, begPos+1, begPos+1)
			if "{" == operand then -- text output
				local endBegPos = string.find(str, "}}", begPos+1, true)
				res = res.."..[===["..string.slice(str, 1, begPos-1).."]===]..tostring(escape("..string.slice(str, begPos+2, endBegPos-1).."))"
				str = string.slice(str, endBegPos+2)
				offsetPos = 1
			elseif "%" == operand then -- code execution
				local endBegPos = string.find(str, "%}", begPos+1, true)
				res = res.."..[===["..string.slice(str, 1, begPos-1).."]===]; "..string.slice(str, begPos+2, endBegPos-1).."\ns = s"
				str = string.slice(str, endBegPos+2)
				offsetPos = 1
			elseif "[" == operand then -- immediate code execution
				local endBegPos = string.find(str, "]}", begPos+1, true)
				res = res.."..[===["..string.slice(str, 1, begPos-1).."]===]"
				local func, err = loadstring(string.slice(str, begPos+2, endBegPos-1))
				if not func then
					Exception(err)
				end
				setfenv(func, {section=function (section)
					self.internal.sections[currentSection] = createFunction(res)
					setfenv(self.internal.sections[currentSection], self.internal)
					currentSection = section
				end})
				func()
				str = string.slice(str, endBegPos+2)
				offsetPos = 1
			else
				offsetPos = begPos+1
			end
		end
		local func = createFunction(res)
		setfenv(func, self.internal)
		return func
	end;
	fetchString = function (self, str)
		return self:compileString(str)()
	end;
	displayString = function (self, str)
		io.write(self:fetchString(str))
	end;
	getTemplateContents = function (self, template)
		if "table" ~= type(self.templatesDirs) or table.isEmpty(self.templatesDirs) then
			local tpl = fs.File(template)
			if tpl:isExists() then
				return tpl:openReadAndClose "*a"
			end
		end
		for _, v in pairs(self.templatesDirs) do
			local tpl = fs.File(v / template)
			if tpl:isExists() then
				return tpl:openReadAndClose "*a"
			end
		end
		Exception("Template "..template.." not found!")
	end;
	fetch = function (self, template)
		return self:compileString(self:getTemplateContents(template))()
	end;
	display = function (self, template)
		io.write(self:fetch(template))
	end;
}

return {Api=Api;Tamplier=Tamplier;Tamplier2=Tamplier2}
