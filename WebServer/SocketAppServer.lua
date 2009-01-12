local tonumber, coroutine, io, setfenv = tonumber, coroutine, io, setfenv
local Object, Socket, String, Exception, Debug, Table = require"ProtOo", require"socket.core", require"String", require"Exception", require"Debug", require"Table"
local _G = _G

module(...)

return Object:extend{
	__tag = "WebServer.SocketAppServer",

	init = function (self, wsApi, host, port)
		self.wsApi = wsApi
		self.host, self.port = host, port
		if not self.host then
			Exception:new"Invalid host!":throw()
		end
		if not self.port then
			Exception:new"Invalid port number!":throw()
		end
		self.server = Socket.tcp()
		if not self.server:bind(self.host, self.port) then
			Exception:new("Can't bind "..self.host..":"..self.port.." to server!"):throw()
		end
		if not self.server:listen(10) then
			Exception:new"Can't listen!":throw()
		end
	end,
	run = function (self, application)
		local client
		while true do
			client = self.server:accept()
			if not client then
				Exception:new"Can't accept connection!":throw()
			end
			local co = coroutine.create(setfenv(function ()
				local wsApi = self.wsApi:new(client)
				application(wsApi)
				wsApi:close()
			end, Table.deepCopy(_G)))
			coroutine.resume(co)
		end
	end
}
