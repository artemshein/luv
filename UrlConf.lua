local Object, Exception = require"ProtOo", require"Exception"
local pairs, string, dump, table, dofile, type, io = pairs, string, dump, table, dofile, type, io

module(...)

local UrlConf = Object:extend{
	init = function (self, wsApi)
		self.uri = wsApi:getRequestHeader("REQUEST_URI")
		local queryPos = string.find(self.uri, "?")
		if queryPos then
			self.uri = string.sub(self.uri, 1, queryPos-1)
		end
	end,
	
	capture = function (self, pos)
		return self.captures[pos]
	end,
	
	dispatch = function (self, urls)
		for expr, script in pairs(urls) do
			local res = {string.find(self.uri, expr)}
			if nil ~= res[1] then
				self.uri = string.sub(self.uri, res[2]+1)
				self.captures = {}
				local i = 3
				for i = 3, #res do
					table.insert(self.captures, res[i])
				end
				if type(script) == "string" then
					dofile(script)
				elseif type(script) == "function" then
					script(self)
				else
					Exception:new"Invalid action!":throw()
				end
				return true
			end
		end
		return false
	end
}

return UrlConf
