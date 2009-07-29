local require, tonumber, type, pairs, io, debug = require, tonumber, type, pairs, io, debug
local Driver = require"luv.db.keyvalue".Driver
local socket = require"socket"
local string, table = require"luv.string", require"luv.table"
local serialize, unserialize = string.serialize, string.unserialize

module(...)

local function get (socket)
	local res = socket:receive()
	if string.slice(res, 1, 1) ~= "$" then
		Driver.Exception"invalid server answer"
	end
	local len = tonumber(string.slice(res, 2))
	if -1 == len then
		res = nil
	else
		res = unserialize(socket:receive(len))
		socket:receive()
	end
	return res
end

local function set (socket, key, value)
	if nil == value then
		socket:send("DEL "..key.."\r\n")
	else
		value = serialize(value)
		socket:send("SET "..key.." "..string.len(value).."\r\n"..value.."\r\n")
	end
	local res = socket:receive()
	if string.slice(res, 1, 1) == "-" then
		Driver.Exception(res)
	end
end

local function status (socket)
	local res = socket:receive()
	if "+OK" ~= res then
		Driver.Exception(res)
	end
end

local RedisDriver = Driver:extend{
	__tag = .....".Driver";
	socket = Driver.property;
	init = function (self, host, login, pass, schema, port, params)
		local tcpSocket, error = socket.connect(host, port or 6379)
		if not tcpSocket then
			Driver.Exception(error)
		end
		if pass then
			tcpSocket:send("AUTH "..pass.."\r\n")
			local res = tcpSocket:receive()
			if string.slice(res, 1, 1) ~= "+" then
				Driver.Exception(res)
			end
		end
		self:socket(tcpSocket)
		self:ping()
	end;
	ping = function (self)
		local socket = self:socket()
		local res, error = socket:send"PING\r\n"
		if not res then
			Driver.Exception(error)
		end
		if "+PONG" ~= socket:receive() then
			return false
		end
		return true
	end;
	get = function (self, keyOrKeys)
		local socket = self:socket()
		if "table" == type(keyOrKeys) then
			socket:send("MGET "..table.join(keyOrKeys, " ").."\r\n")
			local res = socket:receive()
			if string.slice(res, 1, 1) ~= "*" then
				Driver.Exception"invalid server answer"
			end
			local resCount = tonumber(string.slice(res, 2))
			if resCount ~= #keyOrKeys then
				Driver.Exception"invalid answer (number of values)"
			end
			local result = {}
			for i = 1, resCount do
				result[keyOrKeys[i] ] = get(socket)
			end
			return result
		else
			socket:send("GET "..keyOrKeys.."\r\n")
			return get(socket)
		end
	end;
	set = function (self, key, value)
		local socket = self:socket()
		if "table" == type(key) then
			for k, v in pairs(key) do
				set(socket, k, v)
			end
		else
			set(socket, key, value)
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
		local res = socket:receive()
		if string.slice(res, 1, 1) ~= ":" then
			Driver.Exception"invalid server answer"
		end
		return tonumber(string.slice(res, 2))
	end;
	decr = function (self, key, value)
		local socket = self:socket()
		if value then
			socket:send("DECRBY "..key.." "..tonumber(value).."\r\n")
		else
			socket:send("DECR "..key.."\r\n")
		end
		local res = socket:receive()
		if string.slice(res, 1, 1) ~= ":" then
			Driver.Exception"invalid server answer"
		end
		return tonumber(string.slice(res, 2))
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
		local res = socket:receive()
		if string.slice(res, 1, 1) ~= "$" then
			Driver.Exception"inalid server answer"
		end
		local len = tonumber(string.slice(res, 2))
		if 0 == len then
			socket:receive()
			return {}
		end
		res = socket:receive(len)
		socket:receive()
		return string.explode(res, " ")
	end;
	exists = function (self, key)
		local socket = self:socket()
		socket:send("EXISTS "..key.."\r\n")
		local res = socket:receive()
		if string.slice(res, 1, 1) ~= ":" then
			Driver.Exception"invalid server answer"
		end
		return res == ":1" and true or false
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
		local res = socket:receive()
		if ":" ~= string.slice(res, 1, 1) then
			Driver.Exception(res)
		end
		return tonumber(string.slice(res, 2))
	end;
	lrange = function (self, key, from, to)
		local socket = self:socket()
		socket:send("LRANGE "..key.." "..from.." "..to.."\r\n")
		local res = socket:receive()
		if "*" ~= string.slice(res, 1, 1) then
			Driver.Exception"invalid server answer"
		end
		local result = {}
		for i = 1, tonumber(string.slice(res, 2)) do
			result[i] = get(socket)
		end
		return result
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
		value = serialize(socket)
		socket:send("LREM "..key.." "..count.." "..string.len(value).."\r\n"..value.."\r\n")
		local res = socket:receive()
		if ":" ~= string.slice(res, 1, 1) then
			Driver.Exception(res)
		end
		return tonumber(string.slice(res, 2))
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
}

return {Driver=RedisDriver}
