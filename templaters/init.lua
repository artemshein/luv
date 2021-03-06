local string = require "luv.string"
local type, table, ipairs, pairs, io, require = type, table, ipairs, pairs, io, require
local loadstring, setfenv, tostring = loadstring, setfenv, tostring
local Object = require"luv.oop".Object
local fs = require "luv.fs"
local exceptions = require "luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try
local html = require "luv.utils.html"

module(...)

local abstract = Object.abstractMethod
local property = Object.property

local Api = Object:extend{
	__tag = .....".Api";
	urlPrefix = property;
	mediaPrefix = property;
	init = function (self, templatesDirOrDirs, urlPrefix, mediaPrefix)
		if "string" == type(templatesDirOrDirs)
		or (templatesDirOrDirs and templatesDirOrDirs.isA and templatesDirOrDirs:isA(fs.Dir)) then
			self._templatesDirs = {templatesDirOrDirs}
		else
			self._templatesDirs = {}
			if "table" == type(templatesDirOrDirs) then
				for _, v in ipairs(templatesDirOrDirs) do
					self:addTemplatesDir("table" ~= type(v) and fs.Dir(v) or v)
				end
			end
		end
		self:urlPrefix(urlPrefix)
		self:mediaPrefix(mediaPrefix)
	end;
	addTemplatesDir = function (self, dir)
		table.insert(self._templatesDirs, dir)
	end;
	display = abstract;
	fetch = abstract;
	fetchString = abstract;
	displayString = abstract;
	assign = abstract;
	clear = abstract;
}

local SafeHtml = Object:extend{
	__tag = .....".SafeHtml";
	html = property;
	init = function (self, html)
		self:html(html)
	end;
	__tostring = function (self) return tostring(self:html()) end;
}

string.safe = function (self) return SafeHtml(self) end

local Tamplier = Api:extend{
	__tag = .....".Tamplier",
	init = function (self, ...)
		Api.init(self, ...)
		self._cycleCounters = {}
		self._internal = {
			tostring = tostring;
			sections = {};
			escape = function (str)
				if "table" == type(str) and str.isA and str:isA(SafeHtml) then
					return str
				else
					return html.escape(str)
				end
			end;
			url = function (url)
				local urlPrefix = self._internal.urlPrefix
				if urlPrefix and urlPrefix:utf8len() > 0 then
					url = urlPrefix..url
				end
				return SafeHtml(url)
			end;
			media = function (url)
				local urlPrefix = self._internal.mediaPrefix
				if not urlPrefix then
					urlPrefix = self._internal.urlPrefix
				end
				if urlPrefix and urlPrefix:utf8len() > 0 then
					url = urlPrefix..url
				end
				return SafeHtml(url)
			end;
			safe = function (str) return SafeHtml(str) end;
			section = function (section)
				if not self._internal.sections[section] then
					Exception("section "..section.." not found")
				end
				return self._internal.safe(self._internal.sections[section]())
			end;
			includedFiles = {};
			include = function (file, values)
				local oldInternal = self._internal
				if values then
					oldInternal = table.copy(self._internal)
					self:assign(values)
				end
				local includedFiles = self._internal.includedFiles
				if not includedFiles[file] then
					includedFiles[file] = self:templateContents(file)
				end
				local res = self:compileString(includedFiles[file])()
				if values then
					self._internal = oldInternal
				end
				return self._internal.safe(res)
			end;
			cycle = function (index, params)
				if not self._cycleCounters[index] then self._cycleCounters[index] = 1 end
				self._cycleCounters[index] = self._cycleCounters[index] + 1
				return params[self._cycleCounters[index] % #params + 1]
			end;
		}
		self:assign{urlPrefix=self:urlPrefix()}
		self:assign{mediaPrefix=self:mediaPrefix()}
	end;
	assign = function (self, var, value)
		if type(var) == "table" then
			for i, v in pairs(var) do
				self._internal[i] = v
			end
		else
			self._internal[var] = value
		end
		return self
	end;
	compileString = function (self, str)
		local function createFunction (code)
			local func, err = loadstring('local s = ""'..code.." return s")
			if not func then
				Exception(err)
			end
			setfenv(func, self._internal)
			return func
		end
		local currentSection = "main"
		local sectionsStack = {}
		local res = {main=""}
		local offsetPos = 1
		while true do
			local begPos = str:find("{", offsetPos, true)
			if not begPos then
				res[currentSection] = res[currentSection].."..[===["..str.."]===]"
				break
			end
			local operand = str:sub(begPos+1, begPos+1)
			if "{" == operand then -- text output
				local endBegPos = str:find("}}", begPos+1, true)
				res[currentSection] = res[currentSection].."..[===["..str:sub(1, begPos-1).."]===]..tostring(escape("..str:sub(begPos+2, endBegPos-1).."))"
				str = str:sub(endBegPos+2)
				offsetPos = 1
			elseif "%" == operand then -- code execution
				local endBegPos = str:find("%}", begPos+1, true)
				res[currentSection] = res[currentSection].."..[===["..str:sub(1, begPos-1).."]===]; "..str:sub(begPos+2, endBegPos-1).." s = s"
				str = str:sub(endBegPos+2)
				offsetPos = 1
			elseif "[" == operand then -- immediate code execution
				local endBegPos = str:find("]}", begPos+1, true)
				res[currentSection] = res[currentSection].."..[===["..str:sub(1, begPos-1).."]===]"
				local func, err = loadstring(str:sub(begPos+2, endBegPos-1))
				if not func then
					Exception(err)
				end
				setfenv(func,
				{
					extends = function (tpl)
						res.main = self:compileString(self:templateContents(tpl))
						currentSection = "null"
						res[currentSection] = ""
					end;
					section = function (name)
						table.insert(sectionsStack, currentSection)
						currentSection = name
						res[currentSection] = ""
					end;
					endSection = function ()
						self._internal.sections[currentSection] = createFunction(res[currentSection])
						local oldSection = currentSection
						currentSection = table.remove(sectionsStack)
						res[currentSection] = res[currentSection].."..tostring(escape(section "..("%q"):format(oldSection).."))"
					end;
				})
				try(function () func() end):throw()
				str = str:sub(endBegPos+2)
				offsetPos = 1
			else
				offsetPos = begPos+1
			end
		end
		if "function" == type(res.main) then
			return res.main
		end
		return createFunction(res.main)
	end;
	fetchString = function (self, str)
		return self:compileString(str)()
	end;
	displayString = function (self, str)
		io.write(self:fetchString(str))
	end;
	templateContents = function (self, template)
		if "table" ~= type(self._templatesDirs) or table.empty(self._templatesDirs) then
			local tpl = fs.File(template)
			if tpl:exists() then
				return tpl:openReadAndClose"*a"
			end
		end
		for _, v in ipairs(self._templatesDirs) do
			local tpl = fs.File(v / template)
			if tpl:exists() then
				return tpl:openReadAndClose"*a"
			end
		end
		local dirs = ""
		for _, dir in ipairs(self._templatesDirs) do
			dirs = dirs.." "..tostring(dir)
		end
		Exception("template "..template.." not found "..dirs)
	end;
	fetch = function (self, template)
		return self:compileString(self:templateContents(template))()
	end;
	display = function (self, template)
		io.write(self:fetch(template))
		return self
	end;
}

return {Api=Api;Tamplier=Tamplier}
