local io, pairs, tonumber, error, select, tostring = io, pairs, tonumber, error, select, tostring
local Object, Debug, Socket, String, Table = require"Luv.ProtOo", require"Luv.Debug", require"socket.core", require"Luv.String", require"Luv.Table"

module(...)

local write = io.write

return Object:extend{
	__tag = ...,

	init = function (self, client)
		local ch = client:receive(1)
		local request = ""
		while ch ~= ":" do
			if not ch then error"Invalid SCGI request!" end
			request = request..ch
			ch = client:receive(1)
		end
		local len = tonumber(request)
		if not len then error"Invalid SCGI request!" end
		request = request..ch..client:receive(len+1)
		io.write = function (...)
			if not self.headersAlreadySent then
				self:sendHeaders()
			end
			local i
			for i = 1, select("#", ...) do
				client:send(tostring(select(i, ...)))
			end
		end
		local keysAndValues = String.explode(String.slice(request, String.find(request, ":", 1, true)+1, -3), "\0")
		local i
		self.requestHeaders = {}
		for i = 1, Table.maxn(keysAndValues)/2 do
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
		local lowerHeader, k, v = String.lower(header)
		for k, v in pairs(self.responseHeaders) do
			if String.lower(k) == lowerHeader then
				return v
			end
		end
		return nil
	end,
	setResponseHeader = function (self, header, value)
		self.responseHeaders[header] = value
	end,
	sendHeaders = function (self)
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
