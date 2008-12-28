local Object, Exception = require"ProtOo", require"Exception"
local io, os, table, ipairs = io, os, table, ipairs

module(...)

local write = io.write

local Cgi = Object:extend{
	headers = {},
	headersAlreadySent = false,
	SERVER_SOFTWARE = os.getenv"SERVER_SOFTWARE",
	SERVER_NAME = os.getenv"SERVER_NAME",
	GATEWAY_INTERFACE = os.getenv"GATEWAY_INTERFACE",
	SERVER_PROTOCOL = os.getenv"SERVER_PROTOCOL",
	SERVER_PORT = os.getenv"SERVER_PORT",
	REQUEST_METHOD = os.getenv"REQUEST_METHOD",
	PATH_INFO = os.getenv"PATH_INFO",
	PATH_TRANSLATED = os.getenv"PATH_TRANSLATED",
	SCRIPT_NAME = os.getenv"SCRIPT_NAME",
	QUERY_STRING = os.getenv"QUERY_STRING",
	REMOTE_HOST = os.getenv"REMOTE_HOST",
	REMOTE_ADDR = os.getenv"REMOTE_ADDR",
	AUTH_TYPE = os.getenv"AUTH_TYPE",
	REMOTE_USER = os.getenv"REMOTE_USER",
	REMOTE_IDENT = os.getenv"REMOTE_IDENT",
	CONTENT_TYPE = os.getenv"CONTENT_TYPE",
	CONTENT_LENGTH = os.getenv"CONTENT_LENGTH",
	HTTP_ACCEPT = os.getenv"HTTP_ACCEPT",
	HTTP_USER_AGENT = os.getenv"HTTP_USER_AGENT",
	REQUEST_URI = os.getenv"REQUEST_URI",
	Exception = Exception:extend{},

	new = Object.singleton,
	sendHeaders = function (self)
		io.write = write
		for i, header in ipairs(self.headers) do
			io.write(header, "\n")
		end
		io.write"Content-type: text/html\n\n"
		headersAlreadySent = true
	end,
	write = function (self, ...)
		if not headersAlreadySent then self:sendHeaders() end
		write(...)
	end,
	header = function (self, str)
		if headersAlreadySent then self.Exception:new"Headers already sent!":throw() end
		table.insert(self.headers, str)
	end
}

io.write = function (...) Cgi:write(...) end

return Cgi