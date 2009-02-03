require"luv.string"
local io, os, string, pairs = io, os, string, pairs
local Object, Exception = require"luv.oop".Object, require"luv.exceptions".Exception

module(...)

local Exception = Exception:extend{__tag = .....".Exception"}

local Api = Object:extend{
	__tag = .....".Api",
	getRequestHeader = Object.abstractMethod,
	getResponseHeader = Object.abstractMethod,
	setResponseHeader = Object.abstractMethod
}

local write = io.write

local Cgi = Api:extend{
	__tag = .....".Cgi",
	responseHeaders = {},
	headersAlreadySent = false,
	new = function (self)
		io.write = function (...)
			if not self.headersAlreadySent then self:sendHeaders() end
			write(...)
		end
		return self
	end,
	getRequestHeader = function (self, header)
		return os.getenv(header)
	end,
	getResponseHeader = function (self, header)
		local lowerHeader, k, v = string.lower(header)
		for k, v in pairs(self.responseHeaders) do
			if string.lower(k) == lowerHeader then
				return v
			end
		end
		return nil
	end,
	setResponseHeader = function (self, header, value)
		if self.headerAlreadySent then
			Exception"Headers already sent!":throw()
		end
		self.responseHeaders[header] = value
	end,
	sendHeaders = function (self)
		io.write = write
		if not self:getResponseHeader("Content-type") then
			self:setResponseHeader("Content-type", "text/html")
		end
		local k, v
		for k, v in pairs(self.responseHeaders) do
			io.write(k, ":", v, "\n")
		end
		io.write"\n"
		self.headersAlreadySent = true
	end
}

local Scgi = Object:extend{
	__tag = .....".Scgi",
	init = function (self, client)
		local ch = client:receive(1)
		local request = ""
		while ch ~= ":" do
			if not ch then Exception"Invalid SCGI request!":throw() end
			request = request..ch
			ch = client:receive(1)
		end
		local len = tonumber(request)
		if not len then Exception"Invalid SCGI request!":throw() end
		request = request..ch..client:receive(len+1)
		io.write = function (...)
			if not self.headersAlreadySent then self:sendHeaders() end
			local i
			for i = 1, select("#", ...) do
				client:send(tostring(select(i, ...)))
			end
		end
		local keysAndValues = string.explode(String.slice(request, string.find(request, ":", 1, true)+1, -3), "\0")
		local i
		self.requestHeaders = {}
		for i = 1, table.maxn(keysAndValues)/2 do
			self.requestHeaders[keysAndValues[i*2-1]] = keysAndValues[i*2]
		end
		self.request = request
		self.client = client
		self.responseHeaders = {}
		self.headersAlreadySent = false
	end,
	getRequestHeader = function (self, header)
		return self.requestHeaders[header]
	end,
	getResponseHeader = function (self, header)
		local lowerHeader, k, v = string.lower(header)
		for k, v in pairs(self.responseHeaders) do
			if string.lower(k) == lowerHeader then
				return v
			end
		end
		return nil
	end,
	setResponseHeader = function (self, header, value)
		self.responseHeaders[header] = value
	end,
	sendHeaders = function (self)
		if self.headersAlreadySent then return end
		self.headersAlreadySent = true
		if not self:getResponseHeader("Content-type") then
			self:setResponseHeader("Content-type", "text/html")
		end
		local k, v
		for k, v in pairs(self.responseHeaders) do
			io.write(k, ":", v, "\n")
		end
		io.write"\n"
	end,
	close = function (self)
		self.client:close()
	end
}

local SocketAppServer = Object:extend{
	__tag = .....".SocketAppSever",
	init = function (self, wsApi, host, port)
		self.wsApi = wsApi
		self.host, self.port = host, port
		if not self.host then
			Exception"Invalid host!":throw()
		end
		if not self.port then
			Exception"Invalid port number!":throw()
		end
		self.server = Socket.tcp()
		if not self.server:bind(self.host, self.port) then
			Exception("Can't bind "..self.host..":"..self.port.." to server!"):throw()
		end
		if not self.server:listen(10) then
			Exception"Can't listen!":throw()
		end
	end,
	run = function (self, application)
		local client
		while true do
			client = self.server:accept()
			if not client then
				Exception"Can't accept connection!":throw()
			end
			local co = coroutine.create(setfenv(function ()
				local wsApi = self.wsApi(client)
				application(wsApi)
				wsApi:close()
			end, table.deepCopy(_G)))
			local res, fail = coroutine.resume(co)
			if not res then
				io.write(fail)
			end
		end
	end
}

return {
	Exception = Exception,
	Api = Api,
	Cgi = Cgi,
	Scgi = Scgi,
	SocketAppServer = SocketAppServer
}
