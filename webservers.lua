require "luv.debug"
require "luv.string"
local io, os, string, pairs, debug, ipairs, tonumber = io, os, string, pairs, debug, ipairs, tonumber
local Object, Exception = require"luv.oop".Object, require"luv.exceptions".Exception

module(...)

local Exception = Exception:extend{__tag = .....".Exception"}

local Api = Object:extend{
	__tag = .....".Api",
	getRequestHeader = Object.abstractMethod,
	getResponseHeader = Object.abstractMethod,
	setResponseHeader = Object.abstractMethod,
	getCookie = Object.abstractMethod,
	setCookie = Object.abstractMethod,
	getCookies = Object.abstractMethod
}

local urlDecode = function (url)
	return string.gsub(string.gsub(url, "%%(..)", function (s)
		local zero, A = string.byte("0"), string.byte("A")
		local i, j = string.byte(s, 1, 2)
		if i > A then i = i - A + 10 else i = i - zero end
		if j > A then j = j - A + 10 else j = j - zero end
		return string.char(i*16+j)
	end), "[+]", function (s)
		local replace = {
			["+"] = " "
		}
		return replace[s]
	end)
end

local Cgi = Api:extend{
	__tag = .....".Cgi",
	responseHeaders = {},
	headersAlreadySent = false,
	cookies = {},
	get = {},
	post = {},
	new = function (self)
		if not self.write then
			self.write = io.write
			io.write = function (...)
				if not self.headersAlreadySent then self:sendHeaders() end
				self.write(...)
			end
			self:parseCookies()
			self:parseGetData()
			self:parsePostData()
		end
		return self
	end,
	-- Headers
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
		if self.headersAlreadySent then
			Exception "Can't change response headers. Headers already sent!":throw()
		end
		self.responseHeaders[header] = value
		return self
	end,
	-- Get
	getGet = function (self, key) return self.get[key] end,
	setGet = function (self, key, value) self.get[key] = value return self end,
	getGetData = function (self) return self.get end,
	parseGetData = function (self)
		local _, data = string.split(self:getRequestHeader "REQUEST_URI", "?")
		if data then
			data = string.explode(data, "&")
			local v
			for _, v in ipairs(data) do
				local key, val = string.split(v, "=")
				self.get[key] = urlDecode(val)
			end
		end
	end,
	-- Post
	getPost = function (self, key) return self.post[key] end,
	setPost = function (self, key, value) self.post[key] = value return self end,
	getPostData = function (self) return self.post end,
	parsePostData = function (self)
		if self:getRequestHeader "REQUEST_METHOD" ~= "POST" then
			return
		end
		if "application/x-www-form-urlencoded" == self:getRequestHeader "CONTENT_TYPE" then
			local data = io.read(tonumber(self:getRequestHeader "CONTENT_LENGTH"))
			data = string.explode(data, "&")
			local _, v
			for _, v in ipairs(data) do
				local key, val = string.split(v, "=")
				self.post[key] = val
			end
		else
			Exception "Not implemented!":throw()
		end
	end,
	-- Cookies
	parseCookies = function (self)
		local cookieString = self:getRequestHeader "HTTP_COOKIE"
		if not cookieString then
			return nil
		end
		local cookies = string.explode(cookieString, "&")
		local _, v
		for _, v in ipairs(cookies) do
			local name, value = string.split(v, "=")
			self.cookies[name] = value
		end
	end,
	getCookie = function (self, name)
		return self.cookies[name]
	end,
	setCookie = function (self, name, value, expires, domain, path)
		if not name then
			Exception "Name required!":throw()
		end
		local cookie = name.."="
		self.cookies[name] = value
		if value then cookie = cookie..value end
		if expires then
			cookie = cookie..";expires="..expires
		end
		if domain then
			cookie = cookie..";domain="..domain --or self:getRequestHeader "SERVER_NAME") -- SERVER_NAME is should or must be?
		end
		if path then
			cookie = cookie..";path="..path
		end
		self:setResponseHeader("Set-Cookie", cookie)
	end,
	getCookies = function (self)
		return self.cookies
	end,
	sendHeaders = function (self)
		io.write = self.write
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
