local string = require "luv.string"
require "luv.debug"
local os = os
local math, rawset, rawget, tostring, loadstring, type, pairs, debug, getmetatable = math, rawset, rawget, tostring, loadstring, type, pairs, debug, getmetatable
local oop, crypt, fs = require "luv.oop", require "luv.crypt", require "luv.fs"
local Object, File, Dir = oop.Object, fs.File, fs.Dir

module(...)

local sessionGet = function (self, key)
	local res = rawget(self, "parent")[key]
	if res then return res end
	return rawget(self, "data")[key]
end

local sessionSet = function (self, key, value)
	self.data[key] = value
end

local Session = Object:extend{
	__tag = .....".Session",
	cookieName = "LUV_SESS_ID",
	init = function (self, wsApi, storage)
		rawset(self, "wsApi", wsApi)
		rawset(self, "storage", storage)
		local id = wsApi:getCookie(self:getCookieName())
		if not id or #id ~= 12 then
			id = string.slice(tostring(crypt.Md5(math.random(2000000000))), 1, 12)
			wsApi:setCookie(self:getCookieName(), id)
		end
		rawset(self, "id", id)
		rawset(self, "data", string.unserialize(storage:read(id) or "{}"))
		local mt = getmetatable(self)
		mt.__index = sessionGet
		mt.__newindex = sessionSet
	end,
	getId = function (self) return self.id end,
	getCookieName = function (self) return self.cookieName end,
	setCookieName = function (self, name) rawset(self, "cookieName", name) return self end,
	getData = function (self) return self.data end,
	setData = function (self, data) self.data = data self:save() end,
	save = function (self) self.storage:write(self.id, string.serialize(self.data)) end
}

local SessionFile = Object:extend{
	__tag = .....".SessionFile",
	init = function (self, dir)
		self:setDir(dir)
	end,
	getDir = function (self) return self.dir end,
	setDir = function (self, dir) self.dir = Dir(dir) return self end,
	read = function (self, name)
		local f = File(Dir(self.dir:getName()..string.slice(name, 1, 2)):getName()..string.slice(name, 3))
		if not f:isExists() then
			return nil
		end
		return f:openForReading():read"*a"
	end,
	write = function (self, name, value)
		local d = Dir(self.dir:getName()..string.slice(name, 1, 2))
		d:create()
		local f = File(d:getName()..string.slice(name, 3))
		f:openForWriting():write(value):close()
		return true
	end,
	delete = function (self, name)
		File(Dir(self.dir:getName()..string.slice(fileName, 1, 2)):getName()..string.slice(name, 3)):delete()
	end
}

return {
	Session = Session,
	SessionFile = SessionFile
}
