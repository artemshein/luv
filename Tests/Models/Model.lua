local TestCase, Model, Char, Debug, Factory = require"TestCase", require"Models.Model", require"Fields.Char", require"Debug", require"Database.Factory"
local getmetatable, io, require = getmetatable, io, require

module(...)

return TestCase:extend{
	__tag = "Tests.Models.Model",

	validDsn = "mysql://test:test@localhost/test",

	setUp = function (self)
		self.A = Model:extend{
			__tag = "Models.TestA",
			fields = {title = Char:new()}
		}
		self.A:setDb(Factory:connect(self.validDsn))
		self.A:drop()
		self.A:create()
	end,
	tearDown = function (self)
		self.A:drop()
		self.A = nil
	end,
	testAbstract = function (self)
		self.assertThrows(function () Model:new() end)
	end,
	testBasic = function (self)
		local Test = Model:extend{
			__tag = "Models.Test",
			fields = {test = Char:new{minLength = 4, maxLength = 6}}
		}
		local t = Test:new()
		t.test = "123"
		self.assertEquals(t.test, "123")
		self.assertEquals(t.test, t:getField"test":getValue())
		self.assertEquals(t:getField"test":getName(), "test")
		self.assertFalse(t:validate())
		t.test = "1234"
		self.assertTrue(t:validate())
		local t2 = t:clone()
		t2:getField"test":setName"test2"
		self.assertNotNil(t:getField"test")
		self.assertNil(t:getField"test2")
		self.assertNil(t2:getField"test")
		self.assertNotNil(t2:getField"test2")
	end,
	testFindSimple = function (self)
		local lastId = self.A:getDb():insertRow():into(self.A:getTableName()):set("?#=?", "title", "abc"):exec()
		self.assertTrue(lastId)
		local a = self.A:find(lastId)
		self.assertEquals(a.id, lastId)
		self.assertEquals(a.title, "abc")
		a = self.A:find{title = "abc"}
		self.assertEquals(a.title, "abc")
		self.assertEquals(a.id, lastId)
	end,
	testInsertSimple = function (self)
		local a = self.A:new()
		a.title = "testTitle"
		self.assertTrue(a:insert())
		local b = self.A:getDb():selectRow():from(self.A:getTableName()):exec()
		self.assertEquals(b.title, "testTitle")
	end,
	testUpdateSimple = function (self)
		local id = self.A:getDb():insertRow():into(self.A:getTableName()):set("?#=?", "title", "abc"):exec()
		local a = self.A:new()
		a.id = id
		a.title = "cde"
		a:update()
		local b = self.A:getDb():selectRow():from(self.A:getTableName()):where("?#=?n", "id", id):exec()
		self.assertTrue(b.title, "cde")
	end,
}
