local Object, Exception = require"ProtOo", require"Exception"
local io, dump, os = io, dump, os

module(...)

return Object:extend{
	Exception = Exception:extend{},
	
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
