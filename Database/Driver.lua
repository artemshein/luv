local Object = require"ProtOo"

module(...)

local Driver = Object:extend{
	__tag = "Database.Driver",
	
	query = function (self, sql)
		return self.connection:execute(sql)
	end
}

return Driver