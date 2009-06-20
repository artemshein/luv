local string = require "luv.string"
local table = require "luv.table"
local io, os, tostring, require = io, os, tostring, require
local Object, Exception = require "luv.oop".Object, require "luv.exceptions".Exception
local posix = require "posix"

module(...)

local DIR_SEP = "/"

local Exception = Exception:extend{__tag = .....".Exception"}

local Path = Object:extend{
	__tag = .....".Path";
	init = function (self, path) self._path = path end;
	exists = function (self) Exception "not implemented" end;
	__div = function (self, path)
		path = tostring(path)
		if string.endsWith(self._path, "/")
		or string.endsWith(self._path, "\\") then
			if string.beginsWith(path, "/")
			or string.beginsWith(path, "\\") then
				return self.parent(self._path..string.slice(path, 2))
			else
				return self.parent(self._path..path)
			end
		else
			if string.beginsWith(path, "/")
			or string.beginsWith(path, "\\") then
				return self.parent(self._path..path)
			else
				return self.parent(self._path..DIR_SEP..path)
			end
		end
	end;
	__tostring = function (self) return self._path end;
}

local File = Object:extend{
	__tag = .....".File",
	init = function (self, path)
		self._path = path
		if not self._path.isKindOf or not self._path:isKindOf(Path) then
			self._path = Path(self._path)
		end
	end;
	getName = function (self)
		local name = tostring(self._path)
		local begPos, endPos = string.findLast(name, "/")
		if begPos then
			name = string.slice(name, endPos+1)
		end
		begPos, endPos = string.findLast(name, "\\")
		if begPos then
			name = string.slice(name, endPos+1)
		end
		return name
	end;
	openForReading = function (self)
		file, err = io.open(tostring(self._path))
		if not file then
			Exception(err.." "..tostring(self._path))
		end
		self._handle = file
		self._mode = "read"
		return self
	end;
	openForReadingBinary = function (self)
		file, err = io.open(tostring(self._path), "rb")
		if not file then
			Exception(err)
		end
		self._handle = file
		self._mode = "read"
		return self
	end;
	openForWriting = function (self)
		file, err = io.open(tostring(self._path), "w")
		if not file then
			Exception(err)
		end
		self._handle = file
		self._mode = "write"
		return self
	end;
	openForWritingBinary = function (self)
		file, err = io.open(tostring(self._path), "wb")
		if not file then
			Exception(err)
		end
		self._handle = file
		self._mode = "write"
		return self
	end;
	isExists = function (self)
		if self._handle then
			return true
		end
		local res = io.open(tostring(self._path))
		if res then
			io.close(res)
			return true
		end
		return false
	end;
	read = function (self, ...)
		if not self._handle then
			Exception "file must be opened first"
		end
		return self._handle:read(...)
	end,
	readAndClose = function (self, ...)
		local res = self:read(...)
		self:close()
		return res
	end;
	writeAndClose = function (self, ...)
		self:write(...)
		self:close()
		return self
	end;
	openReadAndClose = function (self, ...)
		return self:openForReading():readAndClose(...)
	end;
	openWriteAndClose = function (self, ...)
		return self:openForWriting():writeAndClose(...)
	end;
	write = function (self, ...)
		if (not self._handle) or self._mode ~= "write" then
			Exception "file must be opened in write mode"
		end
		self._handle:write(...)
		return self
	end;
	close = function (self, ...)
		if self._handle then
			self._handle:close(...)
		end
		return self
	end;
	delete = function (self)
		return os.remove(tostring(self._path))
	end;
	__tostring = function (self) return tostring(self._path) end;
}

local Dir = Object:extend{
	__tag = .....".Dir",
	init = function (self, path)
		self._path = path
		if not self._path.isKindOf or not self._path:isKindOf(Path) then
			self._path = Path(self._path)
		end
	end;
	create = function (self)
		os.execute("mkdir "..tostring(self._path))
	end;
	delete = function (self)
		os.execute("rm -r "..tostring(self._path))
	end;
	getFiles = function (self)
		local res = {}
		for f in posix.files(tostring(self._path)) do
			if ".." ~= f and "." ~= f then
				table.insert(res, File(self._path / f))
			end
		end
		return res
	end;
	__div = function (self, path)
		return self._path / path
	end;
	__tostring = function (self) return tostring(self._path) end;
}

return {File=File;Dir=Dir;Path=Path}
