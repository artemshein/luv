local require, tonumber, type, pairs, io, debug = require, tonumber, type, pairs, io, debug
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
		status(socket)
		return self
	end;
	select = function (self, schema)
		local socket = self:socket()
		socket:send("SELECT "..schema.."\r\n")
		status(socket)
		return self
	end;
	get = function (self, keyOrKeys)
		local socket = self:socket()
		if "table" == type(keyOrKeys) then
			socket:send("MGET "..table.join(keyOrKeys, " ").."\r\n")
			return bulk(socket, keyOrKeys)
		else
			socket:send("GET "..keyOrKeys.."\r\n")
			return get(socket)
		end
	end;
	set = function (self, key, value)
		local function setOne (socket, key, value)
			if nil == value then
				socket:send("DEL "..key.."\r\n")
				numeric(socket)
			else
				value = serialize(value)
				socket:send("SET "..key.." "..string.len(value).."\r\n"..value.."\r\n")
				status(socket)
			end
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
				socket:send("DEL "..table.join(key, " ").."\r\n")
				numeric(socket)
			end
		else
			setOne(socket, key, value)
		end
		return self
	end;
	close = function (self) self:socket():send"QUIT" end;
	incr = function (self, key, value)
		local socket = self:socket()
		if value then
			socket:send("INCRBY "..key.." "..tonumber(value).."\r\n")
		else
			socket:send("INCR "..key.."\r\n")
		end
		return numeric(socket)
	end;
	decr = function (self, key, value)
		local socket = self:socket()
		if value then
			socket:send("DECRBY "..key.." "..tonumber(value).."\r\n")
		else
			socket:send("DECR "..key.."\r\n")
		end
		return numeric(socket)
	end;
	flush = function (self)
		local socket = self:socket()
		socket:send("FLUSHDB\r\n")
		status(socket)
		return self
	end;
	keys = function (self, pattern)
		local socket = self:socket()
		socket:send("KEYS "..pattern.."\r\n")
		local res = get(socket, true)
		return res ~= "" and string.explode(res, " ") or {}
	end;
	exists = function (self, key)
		local socket = self:socket()
		socket:send("EXISTS "..key.."\r\n")
		return numeric(socket) == 1
	end;
	rename = function (self, oldname, newname)
		local socket = self:socket()
		socket:send("RENAME "..oldname.." "..newname.."\r\n")
		status(socket)
		return true
	end;
	-- List processing
	lpush = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("LPUSH "..key.." "..string.len(value).."\r\n"..value.."\r\n")
		status(socket)
		return self
	end;
	rpush = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("RPUSH "..key.." "..string.len(value).."\r\n"..value.."\r\n")
		status(socket)
		return self
	end;
	llen = function (self, key)
		local socket = self:socket()
		socket:send("LLEN "..key.."\r\n")
		return numeric(socket)
	end;
	lrange = function (self, key, from, to)
		local socket = self:socket()
		socket:send("LRANGE "..key.." "..from.." "..to.."\r\n")
		return bulk(socket)
	end;
	ltrim = function (self, key, from, to)
		local socket = self:socket()
		socket:send("LTRIM "..key.." "..from.." "..to.."\r\n")
		status(socket)
		return self
	end;
	lindex = function (self, key, index)
		local socket = self:socket()
		socket:send("LINDEX "..key.." "..index.."\r\n")
		return get(socket)
	end;
	lset = function (self, key, index, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("LSET "..key.." "..index.." "..string.len(value).."\r\n"..value.."\r\n")
		status(socket)
		return self
	end;
	lrem = function (self, key, count, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("LREM "..key.." "..count.." "..string.len(value).."\r\n"..value.."\r\n")
		return numeric(socket)
	end;
	lpop = function (self, key)
		local socket = self:socket()
		socket:send("LPOP "..key.."\r\n")
		return get(socket)
	end;
	rpop = function (self, key)
		local socket = self:socket()
		socket:send("RPOP "..key.."\r\n")
		return get(socket)
	end;
	-- Union processing
	sadd = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("SADD "..key.." "..string.len(value).."\r\n"..value.."\r\n")
		return numeric(socket) == 1
	end;
	srem = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("SREM "..key.." "..string.len(value).."\r\n"..value.."\r\n")
		return numeric(socket) == 1
	end;
	smove = function (self, src, dest, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("SMOVE "..src.." "..dest.." "..string.len(value).."\r\n"..value.."\r\n")
		return numeric(socket) == 1
	end;
	scard = function (self, key)
		local socket = self:socket()
		socket:send("SCARD "..key.."\r\n")
		return numeric(socket)
	end;
	sismember = function (self, key, value)
		local socket = self:socket()
		value = serialize(value)
		socket:send("SISMEMBER "..key.." "..string.len(value).."\r\n"..value.."\r\n")
		return numeric(socket) == 1
	end;
	sinter = function (self, keys)
		local socket = self:socket()
		socket:send("SINTER "..table.join(keys, " ").."\r\n")
		return bulk(socket)
	end;
	sinterstore = function (self, dest, keys)
		local socket = self:socket()
		socket:send("SINTERSTORE "..dest.." "..table.join(keys, " ").."\r\n")
		return numeric(socket)
	end;
	sunion = function (self, keys)
		local socket = self:socket()
		socket:send("SUNION "..table.join(keys, " ").."\r\n")
		return bulk(socket)
	end;
	sunionstore = function (self, dest, keys)
		local socket = self:socket()
		socket:send("SUNIONSTORE "..dest.." "..table.join(keys, " ").."\r\n")
		return numeric(socket)
	end;
	sdiff = function (self, keys)
		local socket = self:socket()
		socket:send("SDIFF "..table.join(keys, " ").."\r\n")
		return bulk(socket)
	end;
	sdiffstore = function (self, dest, keys)
		local socket = self:socket()
		socket:send("SDIFFSTORE "..dest.." "..table.join(keys, " ").."\r\n")
		return numeric(socket)
	end;
	smembers = function (self, key)
		local socket = self:socket()
		socket:send("SMEMBERS "..key.."\r\n")
		return bulk(socket)
	end;
}

return {Driver=RedisDriver}
