local string = require"luv.string"
local table = require"luv.table"
local io, os, tostring, require = io, os, tostring, require
local Object, Exception = require"luv.oop".Object, require"luv.exceptions".Exception
local posix = require"posix"

module(...)

local property = Object.property
local DIR_SEP = "/"

local Exception = Exception:extend{__tag = .....".Exception"}

local Path = Object:extend{
	__tag = .....".Path";
	path = property"string";
	init = function (self, path) self:path(tostring(path)) end;
	exists = function (self) Exception"not implemented" end;
	__div = function (self, path2)
		local path = self:path()
		path2 = tostring(path2)
		if path:endsWith"/" or path:endsWith"\\" then
			if path2:beginsWith"/" or path2:beginsWith"\\" then
				return self:parent()(path..path2:slice(2))
			else
				return self:parent()(path..path2)
			end
		else
			if path2:beginsWith"/" or path2:beginsWith"\\" then
				return self:parent()(path..path2)
			else
				return self:parent()(path..DIR_SEP..path2)
			end
		end
	end;
	__tostring = function (self) return self:path() end;
}

local File = Object:extend{
	__tag = .....".File";
	path = property;
	handle = property;
	mode = property"string";
	init = function (self, path)
		if not path.isA or not path:isA(Path) then
			self:path(Path(path))
		else
			self:path(path)
		end
	end;
	name = function (self)
		local name = tostring(self:path())
		local begPos, endPos = name:findLast"/"
		if begPos then
			name = name:slice(endPos+1)
		end
		begPos, endPos = name:findLast"\\"
		if begPos then
			name = name:slice(endPos+1)
		end
		return name
	end;
	openForReading = function (self)
		file, err = io.open(tostring(self:path()))
		if not file then
			Exception(err.." "..tostring(self:path()))
		end
		self:handle(file)
		self:mode"read"
		return self
	end;
	openForReadingBinary = function (self)
		file, err = io.open(tostring(self:path()), "rb")
		if not file then
			Exception(err)
		end
		self:handle(file)
		self:mode"read"
		return self
	end;
	openForWriting = function (self)
		file, err = io.open(tostring(self:path()), "w")
		if not file then
			Exception(err)
		end
		self:handle(file)
		self:mode"write"
		return self
	end;
	openForWritingBinary = function (self)
		file, err = io.open(tostring(self:path()), "wb")
		if not file then
			Exception(err)
		end
		self:handle(file)
		self:mode"write"
		return self
	end;
	exists = function (self)
		if self:handle() then
			return true
		end
		local res = io.open(tostring(self:path()))
		if res then
			io.close(res)
			return true
		end
		return false
	end;
	read = function (self, ...)
		if not self:handle() then
			Exception"file must be opened first"
		end
		return self:handle():read(...)
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
		if (not self:handle()) or self:mode() ~= "write" then
			Exception"file must be opened in write mode"
		end
		self:handle():write(...)
		return self
	end;
	close = function (self, ...)
		if self:handle() then
			self:handle():close(...)
		end
		return self
	end;
	delete = function (self)
		return os.remove(tostring(self:path()))
	end;
	__tostring = function (self) return tostring(self:path()) end;
}

local Dir = Object:extend{
	__tag = .....".Dir";
	path = property;
	init = function (self, path)
		if not path or not path.isA or not path:isA(Path) then
			self:path(Path(path))
		else
			self:path(path)
		end
	end;
	create = function (self)
		os.execute("mkdir "..tostring(self:path()))
	end;
	delete = function (self)
		os.execute("rm -r "..tostring(self:path()))
	end;
	files = function (self)
		local res, path = {}, self:path()
		local files = posix.files(tostring(path))
		if files then
			for f in files do
				if ".." ~= f and "." ~= f then
					table.insert(res, File(path / f))
				end
			end
		end
		return res
	end;
	exists = function (self)
		local stat = posix.stat(tostring(self))
		return stat and stat.type == "directory"
	end;
	__div = function (self, path)
		return self:path() / path
	end;
	__tostring = function (self) return tostring(self:path()) end;
}

return {File=File;Dir=Dir;Path=Path}
