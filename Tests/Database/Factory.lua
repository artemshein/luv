local TestCase, Database, Driver = require"TestCase", require"Database.Factory", require"Database.Driver"
local Debug = require"Debug"

module(...)

local FactoryTest = TestCase:extend{
	invalidDsn = "mysql://invalid-user:invalid-pass@invalid-host/invalid-db", -- This DSN should be invalid!
	validDsn = "mysql://test:test@localhost/test", -- This DSN should be valid!
	testConnect = function (self)
		self.assertThrows(function () Database:connect(self.invalidDsn) end)
		local db = Database:connect(self.validDsn)
		self.assertTrue(db:isKindOf(Driver))
	end
}

return FactoryTest