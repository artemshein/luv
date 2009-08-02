local require, tonumber, type, pairs, io, debug = require, tonumber, type, pairs, io, debug
local ipairs = ipairs
local Driver = require"luv.db.keyvalue".Driver
local socket = require"socket"
local string, table = require"luv.string", require"luv.table"
local serialize, unserialize = string.serialize, string.unserialize

module(...)

local function get (socket, rawFlag)
	local res = socket:receive()
	if string.slice(res, 1, 1) ~= "$" then
		Driver.Exception(res)
	end
	local len = tonumber(string.slice(res, 2))
	if -1 == len then
		res = nil
	else
		res = 0 == len and "" or socket:receive(len)
		socket:receive()
		if not rawFlag then
			res = unserialize(res)
		end
	end
	return res
end

local function status (socket)
	local res = socket:receive()
	if "+" ~= string.slice(res, 1, 1) then
		Driver.Exception(res)
	end
end

local function numeric (socket)
	local res = socket:receive()
	if ":" ~= string.slice(res, 1, 1) then
		Driver.Exception(res)
	end
	return tonumber(string.slice(res, 2))
end

local function bulk (socket, keys)
	local res = socket:receive()
	if "*" ~= string.slice(res, 1, 1) then
		Driver.Exception(res)
	end
	local count = tonumber(string.slice(res, 2))
	local result = {}
	if keys then
		for i = 1, count do
			result[keys[i]] = get(socket)
		end
	else
		for i = 1, count do
			res = get(socket)
			if nil ~= res then
				table.insert(result, res)
			end
		end
	end
	return result
end

local RedisDriver = Driver:extend{
	__tag = .....".Driver";
	socket = Driver.property;
	init = function (self, host, login, pass, schema, port, params)
		local tcpSocket, error = socket.connect(host, port or 6379)
		if not tcpSocket then
			Driver.Exception(error)
		end
		self:socket(tcpSocket)
		if pass then
			self:auth(pass)
		end
		if schema then
			self:select(schema)
		end
	end;
	ping = function (self)
		local socket = self:socket()
		local res, error = socket:send"PING\r\n"
		if not res then
			Driver.Exception(error)
		end
		status(socket)
		return self
	end;
	auth = function (self, pass)
		local socket = self:socket()
		socket:send("AUTH "..pass.."\r\n")
		self._logger"AUTH ****"
		status(socket)
		return self
	end;
	select = function (self, schema)
		local socket = self:socket()
		socket:send("SELECT "..schema.."\r\n")
		self._logger("SELECT "..schema)
		status(socket)
		return self
	end;
	get = function (self, keyOrKeys)
		local socket = self:socket()
		local result, request
		if "table" == type(keyOrKeys) then
			request = "MGET "..table.join(keyOrKeys, " ")
			socket:send(request.."\r\n")
			result = bulk(socket, keyOrKeys)
		else
			request = "GET "..keyOrKeys
			socket:send(request.."\r\n")
			result = get(socket)
		end
		self._logger(request)
		return result
	end;
	set = function (self, key, value)
		local function setOne (socket, key, value)
			local request
			if nil == value then
				request = "DEL "..key
				socket:send(request.."\r\n")
				numeric(socket)
			else
				value = serialize(value)
				request = "SET "..key.." "..string.len(value)
				socket:send(request.."\r\n"..value.."\r\n")
				status(socket)
			end
			self._logger(request)
		end
		local socket = self:socket()
		if "table" == type(key) then
			local delKeys = {}
			for k, v in pairs(key) do
				if nil == v then
					table.insert(delKeys, k)
				else
					setOne(socket, k, v)
				end
			end
			if not table.empty(delKeys) then
				local request = "DEL "..table.join(key, " ")
				socket:send(request.."\r\n")
				self._logger(request)
				numeric(socket)
			end
		else
			setOne(socket, key, value)
		end
		return self
	end;
	del = function (self, keyOrKeys)
		local socket = self:socket()
		local request
		if "table" == type(keyOrKeys) then
			request = "DEL "..table.join(keyOrKeys, " ")
			socket:send(request.."\r\n")
			self._logger(request)
			numeric(socket)
		else
			request = "DEL "..keyOrKeys
			socket:send(request.."\r\n")
			self._logger(request)
			numeric(socket)
		end
		return self
	end;
	close = function (self) self:socket():send"QUIT\r\n" self._logger"QUIT" end;
	incr = function (self, key, value)
		local socket = self:socket()
		local request
		if value then
			request = "INCRBY "..key.." "..tonumber(value)
			socket:send(request.."\r\n")
		else
			request = "INCR "..key
			socket:send(request.."\r\n")
		end
		self._logger(request)
		return numeric(socket)
	end;
	decr = function (self, key, value)
		local socket = self:socket()
		local request
		if value then
			request = "DECRBY "..key.." "..tonumber(value)
			socket:send(request.."\r\n")
		else
			request = "DECR "..key
			socket:send(request.."\r\n")
		end
		self._logger(request)
		return numeric(socket)
	end;
	flush = function (self)
		local socket = self:socket()
		socket:send("FLUSHDB\r\n")
		socket._logger"FLUSHDB"
		status(socket)
		return self
	end;
	keys = function (self, pattern)
		local socket = self:socket()
		local request = "KEYS "..pattern
		socket:send(request.."\r\n")
		self._logger(request)
		local res = get(socket, true)
		return res ~= "" and string.explode(res, " ") or {}
	end;
	exists = function (self, key)
		local socket = self:socket()
		local request = "EXISTS "..key
		socket:send(request.."\r\n")
		self._logger(request)
		return numeric(socket) == 1
	end;
	rename = function (self, oldname, newname)
		local socket = self:socket()
		local request = "RENAME "..oldname.." "..newname
		socket:send(request.."\r\n")
		self._logger(request)
		status(socket)
		return true
	end;
	-- List processing
	lpush = function (self, key, value)
		local socket = self:socket()
		local request = "LPUSH "..key.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		status(socket)
		return self
	end;
	rpush = function (self, key, value)
		local socket = self:socket()
		local request = "RPUSH "..key.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		status(socket)
		return self
	end;
	llen = function (self, key)
		local socket = self:socket()
		local request = "LLEN "..key
		socket:send(request.."\r\n")
		self._logger(request)
		return numeric(socket)
	end;
	lrange = function (self, key, from, to)
		local socket = self:socket()
		local request = "LRANGE "..key.." "..from.." "..to
		socket:send(request.."\r\n")
		self._logger(request)
		return bulk(socket)
	end;
	ltrim = function (self, key, from, to)
		local socket = self:socket()
		local request = "LTRIM "..key.." "..from.." "..to
		socket:send(request.."\r\n")
		self._logger(request)
		status(socket)
		return self
	end;
	lindex = function (self, key, index)
		local socket = self:socket()
		local request = "LINDEX "..key.." "..index
		socket:send(request.."\r\n")
		self._logger(request)
		return get(socket)
	end;
	lset = function (self, key, index, value)
		local socket = self:socket()
		local request = "LSET "..key.." "..index.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		status(socket)
		return self
	end;
	lrem = function (self, key, count, value)
		local socket = self:socket()
		local request = "LREM "..key.." "..count.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		return numeric(socket)
	end;
	lpop = function (self, key)
		local socket = self:socket()
		local request = "LPOP "..key
		socket:send(request.."\r\n")
		self._logger(request)
		return get(socket)
	end;
	rpop = function (self, key)
		local socket = self:socket()
		socket:send("RPOP "..key.."\r\n")
		self._logger(request)
		return get(socket)
	end;
	-- Union processing
	sadd = function (self, key, value)
		local socket = self:socket()
		local request = "SADD "..key.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		return numeric(socket) == 1
	end;
	srem = function (self, key, value)
		local socket = self:socket()
		local request = "SREM "..key.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		return numeric(socket) == 1
	end;
	smove = function (self, src, dest, value)
		local socket = self:socket()
		local request = "SMOVE "..src.." "..dest.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		return numeric(socket) == 1
	end;
	scard = function (self, key)
		local socket = self:socket()
		local request = "SCARD "..key
		socket:send(request.."\r\n")
		self._logger(request)
		return numeric(socket)
	end;
	sismember = function (self, key, value)
		local socket = self:socket()
		local request = "SISMEMBER "..key.." "..string.len(value)
		value = serialize(value)
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request)
		return numeric(socket) == 1
	end;
	sinter = function (self, keys)
		local socket = self:socket()
		local request = "SINTER "..table.join(keys, " ")
		socket:send(request.."\r\n")
		self._logger(request)
		return bulk(socket)
	end;
	sinterstore = function (self, dest, keys)
		local socket = self:socket()
		local request = "SINTERSTORE "..dest.." "..table.join(keys, " ")
		socket:send(request.."\r\n")
		self._logger(request)
		return numeric(socket)
	end;
	sunion = function (self, keys)
		local socket = self:socket()
		local request = "SUNION "..table.join(keys, " ")
		socket:send(request.."\r\n")
		self._logger(request)
		return bulk(socket)
	end;
	sunionstore = function (self, dest, keys)
		local socket = self:socket()
		local request = "SUNIONSTORE "..dest.." "..table.join(keys, " ")
		socket:send(request.."\r\n")
		self._logger(request)
		return numeric(socket)
	end;
	sdiff = function (self, keys)
		local socket = self:socket()
		local request = "SDIFF "..table.join(keys, " ")
		socket:send(request.."\r\n")
		self._logger(request)
		return bulk(socket)
	end;
	sdiffstore = function (self, dest, keys)
		local socket = self:socket()
		local request = "SDIFFSTORE "..dest.." "..table.join(keys, " ")
		socket:send(request.."\r\n")
		self._logger(request)
		return numeric(socket)
	end;
	smembers = function (self, key)
		local socket = self:socket()
		local request = "SMEMBERS "..key
		socket:send(request.."\r\n")
		self._logger(request)
		return bulk(socket)
	end;
}

return {Driver=RedisDriver}
