local WsApi, Exception, String, Debug = require"WebServer.Api", require"Exception", require"String", require"Debug"
local io, os, table, pairs = io, os, table, pairs

module(...)

local write = io.write

local Cgi = WsApi:extend{
	__tag = "WebServer.Cgi",

	responseHeaders = {},
	headersAlreadySent = false,

	new = WsApi.singleton,
	getRequestHeader = function (self, header)
		return os.getenv(header)
	end,
	getResponseHeader = function (self, header)
		local lowerHeader, k, v = String.lower(header)
		for k, v in pairs(self.responseHeaders) do
			if String.lower(k) == lowerHeader then
				return v
			end
		end
		return nil
	end,
	setResponseHeader = function (self, header, value)
		if self.headerAlreadySent then
			self.Exception:new"Headers already sent!":throw()
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

io.write = function (...)
	if not Cgi.headersAlreadySent then Cgi:sendHeaders() end
	write(...)
end

return Cgi
