local string = require "luv.string"
local os, require = os, require
local math, rawset, rawget, tostring, loadstring, type, pairs, debug, getmetatable = math, rawset, rawget, tostring, loadstring, type, pairs, debug, getmetatable
local oop, crypt, fs = require "luv.oop", require "luv.crypt", require "luv.fs"
local Object, File, Dir = oop.Object, fs.File, fs.Dir

module(...)

local Session = Object:extend{
	__tag = .....".Session";
	_cookieName = "LUV_SESS_ID";
	init = function (self, wsApi, storage)
		rawset(self, "_wsApi", wsApi)
		rawset(self, "_storage", storage)
		local id = wsApi:getCookie(self:getCookieName())
		if not id or #id ~= 12 then
			id = string.slice(tostring(crypt.Md5(math.random(2000000000))), 1, 12)
			wsApi:setCookie(self:getCookieName(), id)
		end
		rawset(self, "_id", id)
		rawset(self, "_data", string.unserialize(storage:read(id)) or {})
	end;
	getId = function (self) return self._id end;
	getCookieName = function (self) return self._cookieName end;
	setCookieName = function (self, name) rawset(self, "_cookieName", name) return self end;
	getData = function (self) return self._data end;
	setData = function (self, data) self._data = data self:save() end;
	save = function (self) self._storage:write(self._id, string.serialize(self._data)) end;
	__index = function (self, key)
		local res = rawget(self, "parent")[key]
		if res then return res end
		return rawget(self, "_data")[key]
	end;
	__newindex = function (self, key, value)
		self._data[key] = value
	end;
}

local SessionFile = Object:extend{
	__tag = .....".SessionFile";
	init = function (self, dir)
		self:setDir(dir)
	end;
	getDir = function (self) return self._dir end;
	setDir = function (self, dir)
		self._dir = dir
		if not self._dir.isKindOf or not self._dir:isKindOf(Dir) then
			self._dir = Dir(self._dir)
		end
		return self
	end;
	read = function (self, name)
		local f = File(self._dir / string.slice(name, 1, 2) / string.slice(name, 3))
		if not f:isExists() then
			return nil
		end
		return f:openReadAndClose "*a"
	end;
	write = function (self, name, value)
		local d = Dir(self._dir / string.slice(name, 1, 2))
		d:create()
		local f = File(d / string.slice(name, 3))
		f:openWriteAndClose(value)
		return true
	end;
	delete = function (self, name)
		File(self._dir / string.slice(name, 1, 2) / string.slice(name, 3)):delete()
	end;
}

return {Session=Session;SessionFile=SessionFile}
