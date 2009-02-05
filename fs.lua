require "luv.string"
local io, os, string = io, os, string
local Object, Exception = require"luv.oop".Object, require"luv.exceptions".Exception

module(...)

local Exception = Exception:extend{__tag = .....".Exception"}

local File = Object:extend{
	__tag = .....".File",
	init = function (self, filename)
		self.filename = filename
	end,
	openForReading = function (self)
		file, err = io.open(self.filename)
		if not file then
			Exception(err):throw()
		end
		self.handle = file
		self.mode = "read"
		return self
	end,
	openForWriting = function (self)
		file, err = io.open(self.filename, "w")
		if not file then
			Exception(err):throw()
		end
		self.handle = file
		self.mode = "write"
		return self
	end,
	isExists = function (self)
		if self.handle then
			return true
		end
		local res = io.open(self.filename)
		if res then
			io.close(res)
			return true
		end
		return false
	end,
	read = function (self, ...)
		if not self.handle then
			Exception"File must be opened first!":throw()
		end
		return self.handle:read(...)
	end,
	write = function (self, ...)
		if (not self.handle) or self.mode ~= "write" then
			Exception"File must be opened in write mode!":throw()
		end
		self.handle:write(...)
		return self
	end,
	close = function (self, ...)
		if self.handle then
			self.handle:close(...)
		end
		return self
	end,
	delete = function (self)
		return os.remove(self.filename)
	end
}

local Dir = Object:extend{
	__tag = .....".Dir",
	init = function (self, name)
		self:setName(name)
	end,
	getName = function (self) return self.name end,
	setName = function (self, name)
		self.name = name
		if not (string.endsWith(self.name, "/") or string.endsWith(self.name, "\\")) then
			self.name = self.name.."/"
		end
	end,
	create = function (self)
		os.execute("mkdir "..self:getName())
	end,
	delete = function (self)
		os.execute("rm -r "..self:getName())
	end
}

return {
	File = File,
	Dir = Dir
}
