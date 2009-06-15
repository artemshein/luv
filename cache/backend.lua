local table = require "luv.table"
local string = require "luv.string"
local tostring, io, pairs, ipairs, os, tonumber = tostring, io, pairs, ipairs, os, tonumber
local type, math, unpack = type, math, unpack
local Object = require "luv.oop".Object
local socket = require "socket"
local select = select
local json = require "luv.utils.json"
local serialize, unserialize = string.serialize, string.unserialize
local exceptions = require "luv.exceptions"
local Exception, try = exceptions.Exception, exceptions.try
local crypt = require "luv.crypt"
local mime = require "mime"

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
	clearTags = Object.abstractMethod;
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
	set = function (self, id, data, tags)
		if tags then Exception"Tags unsupported!" end
		self.logger("set "..id)
		self.storage[id] = serialize(data)
	end;
	delete = function (self, id) self.logger("delete "..id) self.storage[id] = nil end;
	clear = function (self) self.logger("clear") self.storage = {} end;
	clearTags = function (self, tags)
		table.imap(tags, function (tag) self:delete(tag) end)
	end;
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
	get = function (self, ...)
		local keysCount = select("#", ...)
		local res = self.backend:get(unpack(table.imap({...}, function (id) return self:mangleId(id) end)))
		if 1 == keysCount then
			return res
		end
		local result = {}
		for i = 1, keysCount do
			local key = select(i, ...)
			result[key] = res[self:mangleId(key)]
		end
		return result
	end;
	set = function (self, id, data, tags, specificLifetime)
		if "table" == type(tags) then
			tags = table.imap(tags, function (tag) return self:mangleId(tag) end)
		end
		return self.backend:set(self:mangleId(id), data, tags, specificLifetime)
	end;
	delete = function (self, id)
		return self.backend:delete(self:mangleId(id))
	end;
	clearTags = function (self, tags)
		return self.backend:clearTags(table.imap(tags, function (tag) return self:mangleId(tag) end))
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
	test = function (self, combined)
		if combined and "table" == type(combined) and "table" == type(combined[1]) and not table.isEmpty(combined[1]) then
			local tags = table.keys(combined[1])
			local tagsActual = self.backend:get(unpack(tags))
			if "table" ~= type(tagsActual) then
				tagsActual = {[tags[1]] = tagsActual}
			end
			for tag, savedTagVersion in pairs(combined[1]) do
				if tagsActual[tag] ~= savedTagVersion then
					return false
				end
			end
		end
		return true
	end;
	get = function (self, ...)
		local keysCount = select("#", ...)
		local values = self.backend:get(...)
		if 1 == keysCount then
			values = {[select(1, ...)] = values}
		end
		local result = {}
		for i = 1, keysCount do
			local key = select(i, ...)
			if "table" == type(values[key]) and not table.isEmpty(values[key]) and self:test(values[key]) then
				result[key] = values[key][2]
			end
		end
		if 1 == keysCount then
			result = result[select(1, ...)]
		end
		return result
	end;
	set = function (self, id, data, tags, specificLifetime)
		local tagsActual = {}
		local tagsWithVersion = {}
		if "table" == type(tags) then
			tags = table.imap(tags, function (tag) return self:mangleTag(tag) end)
			tagsActual = self.backend:get(unpack(tags))
			if "table" ~= type(tagsActual) or 1 == #tagsActual then
				tagsActual = {[tags[1]] = tagsActual}
			end
			for _, tag in ipairs(tags) do
				local tagVersion = tagsActual[tag]
				if not tagVersion then
					tagVersion = self:generateNewTagVersion()
					self.backend:set(tag, tagVersion)
				end
				tagsWithVersion[tag] = tagVersion
			end
		end
		return self.backend:set(id, {tagsWithVersion; data}, nil, specificLifetime)
	end;
	clearTags = function (self, tags)
		for _, tag in ipairs(tags) do
			self.backend:delete(self:mangleTag(tag))
		end
	end;
	clear = function (self) return self.backend:clear() end;
	delete = function (self, id) return self.backend:delete(id) end;
	mangleTag = function (self, tag) return self.prefix.."_"..self.version.."_"..tag end;
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
			Exception("Couldn't connect to "..options.servers[1].host.." on "..options.servers[1].port)
		end
	end;
	get = function (self, ...)
		local keysCount = select("#", ...)
		local keys
		if keysCount < 1 then
			Exception "One or more keys expected!"
		end
		if keysCount == 1 then
			keys = select(1, ...)
		else
			keys = table.join({...}, " ")
		end
		if not self.socket:send("get "..keys.."\r\n") then
			Exception "Send failed"
		end
		local result = {}
		for i = 1, keysCount do
			local answer = self.socket:receive "*l" -- Optimize me? "*a"
			if "END" == answer then break end
			if not string.beginsWith(answer, "VALUE") then
				Exception("Not a valid answer "..answer)
			end
			local _, key, options, size = string.split(answer, " ")
			answer = self.socket:receive(tonumber(size))
			if not answer then
				Exception "Receive failed"
			end
			result[select(i, ...)] = unserialize(mime.unb64(answer))
			if i == keysCount then
				self.socket:receive "*l"
			end
		end
		self.logger("get "..keys)
		if keysCount == 1 then
			result = result[select(1, ...)]
		end
		return result
	end;
	set = function (self, id, data, tags, specificLifetime)
		-- TODO compression flag
		if "table" == type(tags) and not table.isEmpty(tags) then
			Exception "Tags unsupported. Use TagEmuWrapper instead."
		end
		local serialized = (mime.b64(serialize(data)))
		if not self.socket:send("set "..id.." 0 "..tostring(specificLifetime or self.defaultLifetime).." "..tostring(string.len(serialized)).."\r\n"..serialized.."\r\n") then
			Exception "Send failed"
		end
		local res = self.socket:receive"*l"
		return res == "STORED\r\n"
	end;
	delete = function (self, id)
		if not self.socket:send("delete "..id.."\r\n") then
			Exception"Send failed"
		end
		local res = self.socket:receive"*l"
		self.logger("delete "..id)
		return (res == "DELETED\r\n" or res == "NOT_FOUND\r\n")
	end;
	clear = function (self)
		if not self.socket:send "flush_all\r\n" then
			Exception"Send failed"
		end
		self.logger("clear")
		return self.socket:receive "*l" == "OK\r\n"
	end;
	clearTags = function () Exception"Tags unsupported. Use TagEmuWrapper instead." end;
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
