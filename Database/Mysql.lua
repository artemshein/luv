luasql = require"luasql.mysql"

module(...)

local Mysql = Driver:extend{
	__tag = "Database.Mysql",
	
	init = function (self, host, login, pass, database, port, params)
		local mysql = luasql.mysql()
		self.connection = mysql:connect(database, login, pass, host, port)
	end
}

return Mysql