local type, tonumber, tostring = type, tonumber, tostring
local Driver = require"luv.db.keyvalue".Driver
local socket = require"socket"
local serialize, unserialize = string.serialize, string.unserialize
local crypt = require"luv.crypt"

module(...)

local property = Driver.property

local function get (socket, rawFlag)
	local res = socket:receive()
	if not res:beginsWith"$" then
		Driver.Exception(res)
	end
	local len = tonumber(res:slice(2))
	if 0 == len then
		res = nil
	else
		res = socket:receive(len)
		if not rawFlag then
			res = unserialize(res)
		end
	end
	socket:receive()
	return res
end

local function bulk (socket, keys)
	local res = socket:receive()
	if not res:beginsWith"*" then
		Driver.Exception(res)
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

local function status (socket)
	local res = socket:receive()
	if not res:beginsWith"+" then
		Driver.Exception(res)
	end
	return res
end

local RedmapDriver = Driver:extend{
	__tag = .....".Driver";
	socket = property;
	init = function (self, host, login, pass, schema, port, params)
		local tcpSocket, error = socket.connect(host, port or 14077)
		if not tcpSocket then
			Driver.Exception(error)
		end
		self:socket(tcpSocket)
	end;
	ping = function (self)
		local socket = self:socket()
		local res, error = socket:send"PING\r\n"
		if not res then
			Driver.Exception(error)
		end
		self._logger("PING", status(socket))
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
	set = function (self, key, value, rawFlag)
		local function setOne (socket, key, value, rawFlag)
			local request, result
			if nil == value then
				request = "DEL "..key
				socket:send(request.."\r\n")
				result = numeric(socket)
			else
				value = rawFlag and value or serialize(value)
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
					setOne(socket, k, v, rawFlag)
				end
			end
			if not table.empty(delKeys) then
				local request = "DEL "..table.join(key, " ")
				socket:send(request.."\r\n")
				self._logger(request, numeric(socket))
			end
		else
			setOne(socket, key, value, rawFlag)
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
	keys = function (self, pattern)
		local socket = self:socket()
		local request = "KEYS "..pattern
		socket:send(request.."\r\n")
		local res = get(socket, true)
		self._logger(request, res)
		return res and res ~= "" and res:explode" " or {}
	end;
	rename = function (self, oldname, newname)
		local socket = self:socket()
		local request = "RENAME "..oldname.." "..newname
		socket:send(request.."\r\n")
		self._logger(request, status(socket))
		return true
	end;
	mapreduce = function (self, wildcard, map, reduce)
		local socket = self:socket()
		local mapHash, reduceHash = tostring(crypt.Md5(map))
		if map then
			self:set("map:"..mapHash, map, true)
		end
		if reduce then
			reduceHash = tostring(crypt.Md5(reduce))
			self:set("reduce:"..reduceHash, reduce, true)
		end
		local request = "MAPREDUCE "..wildcard.." map:"..mapHash..(reduce and (" reduce:"..reduceHash) or "")
		socket:send(request.."\r\n")
		local res = get(socket)
		self._logger(request, res)
	end;
}

return {Driver=RedmapDriver}
