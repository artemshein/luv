local require, tonumber, type, pairs, io, debug = require, tonumber, type, pairs, io, debug
local ipairs = ipairs
local KeyValueDriver, socket, string, table = require"luv.db".KeyValueDriver, require"socket", require"luv.string", require"luv.table"
local serialize, unserialize = string.serialize, string.unserialize

module(...)

local property = KeyValueDriver.property
local Exception = KeyValueDriver.Exception

local function get (socket, rawFlag)
	local res = socket:receive()
	if not res:beginsWith"$" then
		Exception(res)
	end
	local len = tonumber(res:slice(2))
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
	if not res:beginsWith"+" then
		Exception(res)
	end
	return res
end

local function numeric (socket)
	local res = socket:receive()
	if not res:beginsWith":" then
		Exception(res)
	end
	return tonumber(res:slice(2))
end

local function bulk (socket, keys)
	local res = socket:receive()
	if not res:beginsWith"*" then
		Exception(res)
	end
	local count = tonumber(res:slice(2))
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

local Driver = KeyValueDriver:extend{
	__tag = .....".Driver";
	socket = property;
	init = function (self, host, login, pass, schema, port, params)
		local tcpSocket, error = socket.connect(host, port or 6379)
		if not tcpSocket then
			Exception(error)
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
			Exception(error)
		end
		self._logger("PING", status(socket))
		return self
	end;
	auth = function (self, pass)
		local socket = self:socket()
		socket:send("AUTH "..pass.."\r\n")
		self._logger("AUTH ****", status(socket))
		return self
	end;
	select = function (self, schema)
		local socket = self:socket()
		socket:send("SELECT "..schema.."\r\n")
		self._logger("SELECT "..schema, status(socket))
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
		self._logger(request, result)
		return result
	end;
	set = function (self, key, value)
		local function setOne (socket, key, value)
			local request, result
			if nil == value then
				request = "DEL "..key
				socket:send(request.."\r\n")
				result = numeric(socket)
			else
				value = serialize(value)
				request = "SET "..key.." "..#value
				socket:send(request.."\r\n"..value.."\r\n")
				result = status(socket)
			end
			self._logger(request, result)
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
				self._logger(request, numeric(socket))
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
		else
			request = "DEL "..keyOrKeys
		end
		socket:send(request.."\r\n")
		self._logger(request, numeric(socket))
		return self
	end;
	close = function (self) self:socket():send"QUIT\r\n" self._logger"QUIT" end;
	incr = function (self, key, value)
		local socket = self:socket()
		local request, result
		if value then
			request = "INCRBY "..key.." "..tonumber(value)
			socket:send(request.."\r\n")
		else
			request = "INCR "..key
			socket:send(request.."\r\n")
		end
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	decr = function (self, key, value)
		local socket = self:socket()
		local request, result
		if value then
			request = "DECRBY "..key.." "..tonumber(value)
			socket:send(request.."\r\n")
		else
			request = "DECR "..key
			socket:send(request.."\r\n")
		end
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	flush = function (self)
		local socket = self:socket()
		socket:send("FLUSHDB\r\n")
		self._logger("FLUSHDB", status(socket))
		return self
	end;
	keys = function (self, pattern)
		local socket = self:socket()
		local request = "KEYS "..pattern
		socket:send(request.."\r\n")
		local res = get(socket, true)
		self._logger(request, res)
		return res ~= "" and res:explode" " or {}
	end;
	exists = function (self, key)
		local socket = self:socket()
		local request, result = "EXISTS "..key
		socket:send(request.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result == 1
	end;
	rename = function (self, oldname, newname)
		local socket = self:socket()
		local request = "RENAME "..oldname.." "..newname
		socket:send(request.."\r\n")
		self._logger(request, status(socket))
		return true
	end;
	-- List processing
	lpush = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		local request = "LPUSH "..key.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request, status(socket))
		return self
	end;
	rpush = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		local request = "RPUSH "..key.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request, status(socket))
		return self
	end;
	llen = function (self, key)
		local socket = self:socket()
		local request, result = "LLEN "..key
		socket:send(request.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	lrange = function (self, key, from, to)
		local socket = self:socket()
		local request, result = "LRANGE "..key.." "..from.." "..to
		socket:send(request.."\r\n")
		result = bulk(socket)
		self._logger(request, result)
		return result
	end;
	ltrim = function (self, key, from, to)
		local socket = self:socket()
		local request = "LTRIM "..key.." "..from.." "..to
		socket:send(request.."\r\n")
		self._logger(request, status(socket))
		return self
	end;
	lindex = function (self, key, index)
		local socket = self:socket()
		local request, result = "LINDEX "..key.." "..index
		socket:send(request.."\r\n")
		result = get(socket)
		self._logger(request, result)
		return result
	end;
	lset = function (self, key, index, value)
		local socket = self:socket()
		value = serialize(value)
		local request = "LSET "..key.." "..index.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		self._logger(request, status(socket))
		return self
	end;
	lrem = function (self, key, count, value)
		local socket = self:socket()
		value = serialize(value)
		local request, result = "LREM "..key.." "..count.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	lpop = function (self, key)
		local socket = self:socket()
		local request, result = "LPOP "..key
		socket:send(request.."\r\n")
		result = get(socket)
		self._logger(request, result)
		return result
	end;
	rpop = function (self, key)
		local socket = self:socket()
		socket:send("RPOP "..key.."\r\n")
		result = get(socket)
		self._logger(request, result)
		return result
	end;
	-- Union processing
	sadd = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		local request, result = "SADD "..key.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result == 1
	end;
	srem = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		local request, result = "SREM "..key.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result == 1
	end;
	smove = function (self, src, dest, value)
		local socket = self:socket()
		value = serialize(value)
		local request, result = "SMOVE "..src.." "..dest.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result == 1
	end;
	scard = function (self, key)
		local socket = self:socket()
		local request, result = "SCARD "..key
		socket:send(request.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	sismember = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		local request, result = "SISMEMBER "..key.." "..#value
		socket:send(request.."\r\n"..value.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result == 1
	end;
	sinter = function (self, keys)
		local socket = self:socket()
		local request, result = "SINTER "..table.join(keys, " ")
		socket:send(request.."\r\n")
		result = bulk(socket)
		self._logger(request, result)
		return result
	end;
	sinterstore = function (self, dest, keys)
		local socket = self:socket()
		local request, result = "SINTERSTORE "..dest.." "..table.join(keys, " ")
		socket:send(request.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	sunion = function (self, keys)
		local socket = self:socket()
		local request, result = "SUNION "..table.join(keys, " ")
		socket:send(request.."\r\n")
		result = bulk(socket)
		self._logger(request, result)
		return result
	end;
	sunionstore = function (self, dest, keys)
		local socket = self:socket()
		local request, result = "SUNIONSTORE "..dest.." "..table.join(keys, " ")
		socket:send(request.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	sdiff = function (self, keys)
		local socket = self:socket()
		local request, result = "SDIFF "..table.join(keys, " ")
		socket:send(request.."\r\n")
		result = bulk(socket)
		self._logger(request, result)
		return result
	end;
	sdiffstore = function (self, dest, keys)
		local socket = self:socket()
		local request, result = "SDIFFSTORE "..dest.." "..table.join(keys, " ")
		socket:send(request.."\r\n")
		result = numeric(socket)
		self._logger(request, result)
		return result
	end;
	smembers = function (self, key)
		local socket = self:socket()
		local request, result = "SMEMBERS "..key
		socket:send(request.."\r\n")
		result = bulk(socket)
		self._logger(request, result)
		return result
	end;
}

return {Driver=Driver}
