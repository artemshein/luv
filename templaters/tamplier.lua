local io, string, loadstring, dump, setfenv, type, pairs, table = io, string, loadstring, dump, setfenv, type, pairs, table
local Templater, fs, Exception = require"luv.templaters".Api, require"luv.fs", require"luv.exceptions".Exception
local File = fs.File

module(...)

return Templater:extend{
	__tag = ...,
	init = function (self, ...)
		Templater.init(self, ...)
		self.internal = {
			includedFiles = {},
			include = function (file)
				local includedFiles = self.internal.includedFiles
				if not includedFiles[file] then
					includedFiles[file] = File(file):openForReading():read"*a"
				end
				return self:compileString(includedFiles[file])
			end
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
		local res = string.gsub(str, "{{", "]===]..")
		res = string.gsub(res, "}}", "..[===[")
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
	fetch = function (self, template)
		local _, v
		for _, v in pairs(self.templatesDirs) do
			local tpl = File(v..template)
			if tpl:isExists() then
				local contents = tpl:openForReading():read("*a")
				tpl:close()
				return self:compileString(contents)
			end
		end
		Exception("Template "..template.." not found!"):throw()
	end,
	display = function (self, template)
		io.write(self:fetch(template))
	end
}
