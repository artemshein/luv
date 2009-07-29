local require, tonumber, type, pairs = require, tonumber, type, pairs
local Driver = require"luv.db.keyvalue".Driver
local socket = require"socket"
local string, table = require"luv.string", require"luv.table"
local serialize, unserialize = string.serialize, string.unserialize

module(...)

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
		local res, error = self:socket():send"PING\r\n"
		if not res then
			Driver.Exception(error)
		end
		if "+PONG" ~= self:socket():receive() then
			return false
		end
		return true
	end;
	get = function (self, keyOrKeys)
		local function get (socket)
			local res = socket:receive()
			if string.slice(res, 1, 1) ~= "$" then
				Driver.Exception"invalid server answer"
			end
			local len = tonumber(string.slice(res, 2))
			res = -1 == len and nil or unserialize(socket:receive(len))
			socket:receive()
			return res
		end
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
				result[keyOrKeys[i]] = get(socket)
			end
			return result
		else
			socket:send("GET "..keyOrKeys.."\r\n")
			return get(socket)
		end
	end;
	set = function (self, key, value)
		local socket = self:socket()
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
		if "+OK" ~= socket:receive() then
			Driver.Exception"invalid server answer"
		end
		return self
	end;
	keys = function (self, pattern)
		local socket = self:socket()
		socket:send("KEYS "..pattern.."\r\n")
		local res = socket:receive()
		if string.slice(res, 1, 1) ~= "$" then
			Driver.Exception"inalid server answer"
		end
		res = socket:receive(tonumber(string.slice(res, 2)))
		--socket:receive()
		return table.explode(res)
	end;
}

return {Driver=RedisDriver}
