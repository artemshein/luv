local table = require "luv.table"
local string = require "luv.string"
local debug = require "luv.debug"
local tostring, io, pairs, ipairs, os, tonumber = tostring, io, pairs, ipairs, os, tonumber
local type, math = type, math
local Object = require "luv.oop".Object
local socket = require "socket"
local json = require "luv.utils.json"
local serialize, unserialize = string.serialize, string.unserialize
local Exception = require "luv.exceptions".Exception
local crypt = require "luv.crypt"

module(...)

-- Main idea has been stolen from dklab.ru PHP classes.
-- Big thanks goes to Dmitry Koterov.

local Backend = Object:extend{
	__tag = .....".Backend";
	logger = function () end;
	get = Object.abstractMethod;
	set = Object.abstractMethod;
	delete = Object.abstractMethod;
	clear = Object.abstractMethod;
	getDefaultLifetime = Object.abstractMethod;
	setDefaultLifetime = Object.abstractMethod;
	setLogger = Object.abstractMethod;
}

local Memory = Backend:extend{
	__tag = .....".Memory";
	init = function (self)
		self.storage = {}
	end;
	get = function (self, id)
		local data = self.storage[id]
		if not data then self.logger("not found "..id) return nil end
		self.logger("get "..id)
		return unserialize(data)
	end;
	set = function (self, id, data) self.logger("set "..id) self.storage[id] = serialize(data) end;
	delete = function (self, id) self.logger("delete "..id) self.storage[id] = nil end;
	clear = function (self) self.logger("clear") self.storage = {} end;
	getDefaultLifetime = function () return 0 end;
	setDefaultLifetime = function () return self end;
	setLogger = function (self, logger)
		self.logger = logger
		return self
	end;
}

local NamespaceWrapper = Backend:extend{
	__tag = .....".NamespaceWrapper";
	init = function (self, backend, namespace)
		self.backend = backend
		self.namespace = namespace
	end;
	get = function (self, id, doNotTestCacheValidity)
		return self.backend:get(self:mangleId(id), doNotTestCacheValidity)
	end;
	set = function (self, id, data, tags, specificLifetime)
		if tags then
			tags = table.copy(tags)
			local i, v
			for i, v in ipairs(tags) do
				tags[i] = self:mangleId(v)
			end
		end
		return self.backend:set(self:mangleId(id), data, tags, specificLifetime)
	end;
	delete = function (self, id)
		return self.backend:delete(self:mangleId(id))
	end;
	clearTags = function (self, tags)
		local _, tag
		for _, tag in ipairs(tags) do
			self.backend:delete(self:mangleId(tag))
		end
	end;
	clear = function (self) return self.backend:clean() end;
	mangleId = function (self, id) return self.namespace.."_"..id end;
	getDefaultLifetime = function (self) return self.backend:getDefaultLifetime() end;
	setDefaultLifetime = function (self, lifetime) return self.backend:setDefaultLifetime(lifetime) end;
	setLogger = function (self, logger) return self.backend:setLogger(logger) end;
}

local TagEmuWrapper = Backend:extend{
	__tag = .....".TagEmuWrapper";
	version = "01";
	prefix = "TagEmuWrapper";
	init = function (self, backend)
		self.backend = backend
	end;
	get = function (self, id, doNotTestCacheValidity)
		return self:loadOrTest(id, doNotTestCacheValidity)
	end;
	set = function (self, id, data, tags, specificLifetime)
		local tagsWithVersion = {}
		if "table" == type(tags) then
			local _, tag
			for _, tag in ipairs(tags) do
				local mangledTag = self:mangleTag(tag)
				local tagVersion = self.backend:get(mangledTag)
				if not tagVersion then
					tagVersion = self:generateNewTagVersion()
					self.backend:set(mangledTag, tagVersion)
				end
				tagsWithVersion[tag] = tagVersion
			end
		end
		local combined = {tagsWithVersion; data}
		return self.backend:set(id, combined, nil, specificLifetime)
	end;
	clearTags = function (self, tags)
		if "table" == type(tags) then
			local _, tag
			for _, tag in ipairs(tags) do
				self.backend:delete(self:mangleTag(tag))
			end
		end
	end;
	clear = function (self) return self.backend:clear() end;
	test = function (self, id) return self:loadOrTest(id, false, true) end;
	delete = function (self, id) return self.backend:delete(id) end;
	mangleTag = function (self, tag) return self.prefix.."_"..self.version.."_"..tag end;
	loadOrTest = function (self, id, doNotTestCacheValidity, returnTrueIfValid)
		local combined = self.backend:get(id, doNotTestCacheValidity)
		if not combined then return nil end
		if "table" ~= type(combined) then return nil end
		if "table" == type(combined[1]) then
			local tag, savedTagVersion
			for tag, savedTagVersion in pairs(combined[1]) do
				local actualTagVersion = self.backend:get(self:mangleTag(tag))
				if actualTagVersion ~= savedTagVersion then
					return nil
				end
			end
		end
		return returnTrueIfValid and true or combined[2]
	end;
	generateNewTagVersion = function (self)
		self.counter = self.counter or 0
		self.counter = self.counter + 1
		return tostring(crypt.hash("md5", tostring(math.random(1, 2000000000))..tostring(counter)))
	end;
	getDefaultLifetime  = function (self)
		return self.backend:getDefaultLifetime()
	end;
	setDefaultLifetime = function (self, lifetime)
		return self.backend:setDefaultLifetime(lifetime)
	end;
	setLogger = function (self, logger) self.backend:setLogger(logger) return self end;
}

local Memcached = Backend:extend{
	__tag = .....".Memcached";
	defaultHost = "127.0.0.1";
	defaultPort = 11211;
	defaultPersistent = true;
	defaultLifetime = 3600;
	init = function (self, options)
		options = options or {}
		if not options.servers then
			options = {servers=options;compression=false}
		end
		if table.isEmpty(options.servers) then
			options.servers = {{
				host = self.defaultHost;
				port = self.defaultPort;
				persistent = self.defaultPersistent;
			}}
		end
		self.options = options
		self.socket = socket.tcp()
		self.socket:connect(options.servers[1].host, options.servers[1].port)
		if not self.socket then
			Exception("Couldn't connect to "..options.servers[1].host.." on "..options.servers[1].port):throw()
		end
	end;
	get = function (self, id, doNotTestCacheValidity)
		if not self.socket:send("get "..id.."\r\n") then
			Exception"Send failed":throw()
		end
		local res = self.socket:receive"*l" -- Optimize me? "*a"
		if "END" == res then self.logger("not found "..id) return nil end
		if not string.beginsWith(res, "VALUE") then
			Exception("Not a valid answer "..res):throw()
		end
		local _, key, options, size = string.split(res, " ")
		res = self.socket:receive(tonumber(size))
		if not res then
			Exception"Receive failed":throw()
		end
		self.socket:receive"*l"
		self.logger("get "..id)
		io.write(string.len(res), res)
		return unserialize(res)
	end;
	set = function (self, id, data, tags, specificLifetime)
		-- TODO compression flag
		if tags and not table.isEmpty(tags) then
			Exception"Tags unsupported. Use TagEmuWrapper instead.":throw()
		end
		local serialized = serialize(data)
		io.write(string.len(serialized), serialized)
		if not self.socket:send("set "..id.." 0 "..tostring(specificLifetime or self.defaultLifetime).." "..tostring(string.len(serialized)).."\r\n"..serialized.."\r\n") then
			Exception"Send failed":throw()
		end
		local res = self.socket:receive"*l"
		return res == "STORED\r\n"
	end;
	delete = function (self, id)
		if not self.socket:send("delete "..id.."\r\n") then
			Exception"Send failed":throw()
		end
		local res = self.socket:receive"*l"
		self.logger("delete "..id)
		return (res == "DELETED\r\n" or res == "NOT_FOUND\r\n")
	end;
	clear = function (self)
		if not self.socket:send "flush_all\r\n" then
			Exception"Send failed":throw()
		end
		self.logger("clear")
		return self.socket:receive "*l" == "OK\r\n"
	end;
	getDefaultLifetime = function (self) return self.defaultLifetime end;
	setDefaultLifetime = function (self, defaultLifetime)
		self.defaultLifetime = defaultLifetime
		return self
	end;
	setLogger = function (self, logger)
		self.logger = logger
		return self
	end;
}

return {Backend=Backend;NamespaceWrapper=NamespaceWrapper;TagEmuWrapper=TagEmuWrapper;Memcached=Memcached;Memory=Memory}
