local UnitTest, Database = require"UnitTest", require"Database.Factory"

module(...)

local FactoryTest = UnitTest:extend{
	testConnect = function (self)
		Database:connect("mysql://login:pass@host/database")
	end
}

return FactoryTest