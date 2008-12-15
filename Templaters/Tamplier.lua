local Templater, File = require"Templaters.Templater", require"File"
local io, string, loadstring, dump, setfenv, type, pairs = io, string, loadstring, dump, setfenv, type, pairs

module(...)

local Tamplier = Templater:extend{
	__tag = "Templaters.Tamplier",
	
	init = function (self, ...)
		self.parent:init(...)
		self.internal = {
			includedFiles = {},
			include = function (file)
				local includedFiles = self.internal.includedFiles
				if not includedFiles[file] then
					includedFiles[file] = File:new(file):openForReading():read"*a"
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
			Exception:new(err):throw()
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
		local template = File:new(self.templatesDir..template)
		local contents = template:openForReading():read("*a")
		template:close()
		return self:compileString(contents)
	end,
	display = function (self, template)
		io.write(self:fetch(template))
	end
}

return Tamplier