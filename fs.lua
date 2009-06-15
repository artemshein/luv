local string = require "luv.string"
local io, os, tostring = io, os, tostring
local Object, Exception = require "luv.oop".Object, require "luv.exceptions".Exception

module(...)

local DIR_SEP = "/"

local Exception = Exception:extend{__tag = .....".Exception"}

local File = Object:extend{
	__tag = .....".File",
	init = function (self, filename)
		self.filename = tostring(filename)
	end,
	openForReading = function (self)
		file, err = io.open(self.filename)
		if not file then
			Exception(err..' '..self.filename)
		end
		self.handle = file
		self.mode = "read"
		return self
	end,
	openForReadingBinary = function (self)
		file, err = io.open(self.filename, 'rb')
		if not file then
			Exception(err)
		end
		self.handle = file
		self.mode = "read"
		return self
	end;
	openForWriting = function (self)
		file, err = io.open(self.filename, 'w')
		if not file then
			Exception(err)
		end
		self.handle = file
		self.mode = "write"
		return self
	end,
	openForWritingBinary = function (self)
		file, err = io.open(self.filename, 'wb')
		if not file then
			Exception(err)
		end
		self.handle = file
		self.mode = "write"
		return self
	end;
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
			Exception"File must be opened first!"
		end
		return self.handle:read(...)
	end,
	readAndClose = function (self, ...)
		local res = self:read(...)
		self:close()
		return res
	end;
	openReadAndClose = function (self, ...)
		return self:openForReading():readAndClose(...)
	end;
	write = function (self, ...)
		if (not self.handle) or self.mode ~= "write" then
			Exception"File must be opened in write mode!"
		end
		self.handle:write(...)
		return self
	end;
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
		self:setName(tostring(name))
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

local Path = Object:extend{
	__tag = .....".Path";
	init = function (self, path) self.path = path end;
	exists = function (self) Exception "not implemented!" end;
	__div = function (self, path)
		path = tostring(path)
		if string.endsWith(self.path, "/")
		or string.endsWith(self.path, "\\") then
			if string.beginsWith(path, "/")
			or string.beginsWith(path, "\\") then
				return self.parent(self.path..string.slice(path, 2))
			else
				return self.parent(self.path..path)
			end
		else
			if string.beginsWith(path, "/")
			or string.beginsWith(path, "\\") then
				return self.parent(self.path..path)
			else
				return self.parent(self.path..DIR_SEP..path)
			end
		end
		return self
	end;
	__tostring = function (self) return self.path end;
}

return {File=File;Dir=Dir;Path=Path;}
