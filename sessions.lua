local string = require "luv.string"
local os, require, select, io = os, require, select, io
local math, rawset, rawget, tostring, loadstring, type, pairs, debug, getmetatable = math, rawset, rawget, tostring, loadstring, type, pairs, debug, getmetatable
local oop, crypt, fs = require "luv.oop", require "luv.crypt", require "luv.fs"
local Object, File, Dir = oop.Object, fs.File, fs.Dir

module(...)

local property = Object.property

local Session = Object:extend{
	__tag = .....".Session";
	__index = function (self, key)
		local res = rawget(self, "_parent")[key]
		if res then return res end
		return rawget(self, "_data")[key]
	end;
	__newindex = function (self, key, value)
		rawget(self, "_data")[key] = value
	end;
	_cookieName = "LUV_SESS_ID";
	init = function (self, wsApi, storage)
		rawset(self, "_wsApi", wsApi)
		rawset(self, "_storage", storage)
		local id = wsApi:cookie(self._cookieName)
		if not id or #id ~= 12 then
			id = string.slice(tostring(crypt.Md5(math.random(2000000000))), 1, 12)
			wsApi:cookie(self._cookieName, id)
		end
		rawset(self, "_id", id)
		local data = storage:read(id)
		rawset(self, "_data", string.unserialize(data) or {})
		rawset(self, "_storedData", data)
	end;
	data = property(nil, function (self) return rawget(self, "_data") end, function (self, data)
		rawset(self, "_data", data)
		return self
	end);
	save = function (self)
		local serializedData = string.serialize(rawget(self, "_data"))
		if serializedData ~= rawget(self, "_storedData") then
			self._storage:write(self._id, serializedData)
			rawset(self, "_storedData", serializedData)
		end
	end;
}

local SessionFile = Object:extend{
	__tag = .....".SessionFile";
	init = function (self, dir)
		self:dir(dir)
	end;
	dir = property(nil, nil, function (self, dir)
		if not dir.isA or not dir:isA(Dir) then
			self._dir = Dir(dir)
		else
			self._dir = dir
		end
		return self
	end);
	read = function (self, name)
		local f = File(self:dir() / string.slice(name, 1, 2) / string.slice(name, 3))
		if not f:exists() then
			return nil
		end
		return f:openReadAndClose"*a"
	end;
	write = function (self, name, value)
		local d = Dir(self:dir() / string.slice(name, 1, 2))
		d:create()
		local f = File(d / string.slice(name, 3))
		f:openWriteAndClose(value)
		return true
	end;
	delete = function (self, name)
		File(self:dir() / string.slice(name, 1, 2) / string.slice(name, 3)):delete()
	end;
}

return {Session=Session;SessionFile=SessionFile}
