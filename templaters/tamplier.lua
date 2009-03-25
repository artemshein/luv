local io, string, loadstring, dump, setfenv, type, pairs, table = io, string, loadstring, dump, setfenv, type, pairs, table
local Templater, fs, Exception = require"luv.templaters".Api, require"luv.fs", require"luv.exceptions".Exception
local tostring = tostring
local File = fs.File

module(...)

local cycleCounters = {}

return Templater:extend{
	__tag = ...,
	init = function (self, ...)
		Templater.init(self, ...)
		self.internal = {
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
				if not cycleCounters[index] then cycleCounters[index] = 0 end
				cycleCounters[index] = cycleCounters[index] + 1
				return params[cycleCounters[index] % table.maxn(params) + 1]
			end;
		}
	end,
	assign = function (self, var, value)
		if type(var) == "table" then
			for i, v in pairs(var) do
				self.internal[i] = v
			end
		else
			self.internal[var] = value
		end
	end,
	compileString = function (self, str)
		local res = string.gsub(str, "{{", "]===]..tostring(")
		res = string.gsub(res, "}}", ")..[===[")
		res = string.gsub(res, "{%%", "]===]\n")
		res = "local s = [===["..string.gsub(res, "%%}", "\ns = s..[===[").."]===]\nreturn s"
		local func, err = loadstring(res)
		if not func then
			Exception(err):throw()
		end
		setfenv(func, self.internal)
		return func()
	end,
	fetchString = function (self, str)
		return self:compileString(str)
	end,
	displayString = function (self, str)
		io.write(self:fetchString(str))
	end,
	getTemplateContents = function (self, template)
		local _, v
		for _, v in pairs(self.templatesDirs) do
			local tpl = File(v..template)
			if tpl:isExists() then
				local contents = tpl:openForReading():read("*a")
				tpl:close()
				return contents
			end
		end
		Exception("Template "..template.." not found!"):throw()
	end;
	fetch = function (self, template)
		return self:compileString(self:getTemplateContents(template))
	end,
	display = function (self, template)
		io.write(self:fetch(template))
	end
}
