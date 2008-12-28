local Object, Cgi, Exception = require"ProtOo", require"Cgi", require"Exception"
local pairs, string, dump, table, dofile = pairs, string, dump, table, dofile

module(...)

local UrlConf = Object:extend{
	init = function (self)
		self.uri = Cgi.REQUEST_URI
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
				dofile(script)
				return true
			end
		end
		return false
	end
}

return UrlConf