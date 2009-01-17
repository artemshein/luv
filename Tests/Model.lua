local Db, Fields, TestCase = from"Luv":import("Db", "Fields", "TestCase")

module(...)

-- ManyToOne

local T01Group = Db.Model:extend{
	__tag = .....".T01Group",

	label = "group", labelMany = "groups",

	number = Fields.Int{pk = true}
}

local T01Student = Db.Model:extend{
	__tag = .....".T01Student",

	label = "student", labelMany = "students",

	name = Fields.Char{pk = true},
	group = Fields.ManyToOne{references=T01Group, required=true, relatedName="students"}
}

-- ManyToMany

local T02Category = Db.Model:extend{
	__tag = .....".T02Category",

	label = "category", labelMany = "categories",

	title = Fields.Char{required=true}
}

local T02Article = Db.Model:extend{
	__tag = .....".T02Article",

	label = "article", labelMany = "articles",

	title = Fields.Char{required=true},
	categories = Fields.ManyToMany{references=T02Category, required=true, relatedName="articles"}
}

-- OneToOne

local T03Man = Db.Model:extend{
	__tag = .....".T03Man",

	label = "man", labelMany = "men",

	name = Fields.Char{required = true}
}

local T03Student = Db.Model:extend{
	__tag = .....".T03Student",

	label = "student", labelMany = "students",

	man = Fields.OneToOne{references=T03Man, primaryKey=true, relatedName="student"},
	group = Fields.Int{required = true}
}
--[[
local T04Man = Model:extend{
	__tag = .....".T01Man",

	name = Char{primaryKey = true},
	friends = ManyToMany"self"
}]]

local validDsn = "mysql://test:test@localhost/test"

return TestCase:extend{
	__tag = ...,

	validDsn = validDsn,

	setUp = function (self)
		self.A = Db.Model:extend{
			label = "a", labelMany = "as",
			fields = {title = Fields.Char()}
		}
		self.A:setDb(Db.Factory:connect(self.validDsn))
		self.A:dropTables()
		self.A:createTables()
	end,
	tearDown = function (self)
		self.A:dropTables()
		self.A = nil
	end,
	testAbstract = function (self)
		self.assertThrows(function () Db.Model() end)
	end,
	testBasic = function (self)
		local Test = Db.Model:extend{
			label = "a", labelMany = "as",
			test = Fields.Char{minLength = 4, maxLength = 6}
		}
		local t = Test()
		t.test = "123"
		self.assertEquals(t.test, "123")
		self.assertEquals(t.test, t:getField"test":getValue())
		self.assertFalse(t:validate())
		t.test = "1234"
		self.assertTrue(t:validate())
	end,
	testFindSimple = function (self)
		local lastId = self.A:getDb():InsertRow():into(self.A:getTableName()):set("?#=?", "title", "abc"):exec()
		self.assertTrue(lastId)
		local a = self.A:find(lastId)
		self.assertEquals(a.id, lastId)
		self.assertEquals(a.title, "abc")
		a = self.A:find{title = "abc"}
		self.assertEquals(a.title, "abc")
		self.assertEquals(a.id, lastId)
	end,
	testInsertSimple = function (self)
		local a = self.A()
		a.title = "testTitle"
		self.assertTrue(a:insert())
		local b = self.A:getDb():SelectRow():from(self.A:getTableName()):exec()
		self.assertEquals(b.title, "testTitle")
	end,
	testUpdateSimple = function (self)
		local id = self.A:getDb():InsertRow():into(self.A:getTableName()):set("?#=?", "title", "abc"):exec()
		local a = self.A()
		a.id = id
		a.title = "cde"
		a:update()
		local b = self.A:getDb():SelectRow():from(self.A:getTableName()):where("?#=?n", "id", id):exec()
		self.assertTrue(b.title, "cde")
	end,
	testT01 = function (self)
		local Student, Group = T01Student, T01Group
		local db = Db.Factory:connect(self.validDsn)
		Student:setDb(db)
		Group:setDb(db)
		Student:dropTables()
		Group:dropTables()
		Group:createTables()
		Student:createTables()


		local max = Student{name="Max"}
		self.assertEquals(max.name, "Max")
		self.assertThrows(function() max:insert() end) -- Student without group throws
		-- Group
		local g581 = Group(581)
		self.assertEquals(g581.number, 581)
		self.assertTrue(g581:insert())
		self.assertEquals(g581.number, 581)
		max.group = g581
		self.assertTrue(max:insert())
		-- Second student
		local john = Student{name="John", group=g581}
		self.assertEquals(john.name, "John")
		self.assertEquals(john.group, g581)
		self.assertTrue(john:save())
		-- Third student
		local peter = Student:create{name="Peter", group=g581}
		self.assertEquals(peter.name, "Peter")
		self.assertEquals(peter.group, g581)
		-- Find Peter
		peter = Student:find"Peter"
		self.assertEquals(peter.name, "Peter")
		self.assertEquals(peter.group, g581)
		self.assertNotEquals(peter.group, Group())
		-- Tests backward relation
		self.assertEquals(g581.students:count(), 3)
		local liza = Student:create{name="Liza", group=g581}
		self.assertEquals(g581.students:count(), 4)
		local g372 = Group:create(372)
		g372.students:add(peter)
		self.assertEquals(g372.students:count(), 1)
		self.assertEquals(g581.students:count(), 3)
		g372.students:add(john, max)
		self.assertEquals(g372.students:count(), 3)
		self.assertEquals(g372.students:filter{name="Max"}:count(), 1)
		self.assertEquals(g372.students:all():filter{name__exact="Max"}:count(), 1)
		self.assertEquals(g372.students:filter{name__beginswith="Ma"}:count(), 1)
		self.assertEquals(g372.students:filter{name__endswith="hn"}:count(), 1)
		self.assertEquals(g372.students:filter{name__contains="a"}:count(), 1)
		self.assertEquals(g372.students:filter"Max":count(), 1)
		self.assertEquals(g372.students:all():filter{name__in={"Max", "John", "Mary"}}:count(), 2)
		self.assertEquals(g372.students:exclude"Max":count(), 2)
		self.assertEquals(g372.students:exclude{name__in={"Max", "John", "Fil"}}:count(), 1)
		self.assertEquals(g581.students:count(), 1)

		self.assertEquals(g372.students:all().Max.group, g372)
		self.assertEquals(g372.students:all().John.group, g372)
		self.assertEquals(g372.students:all().Peter.group, g372)
		self.assertNil(g372.students:all().Kevin)
		-- Can not remove references with required restriction
		self.assertThrows(function() g372.students:remove() end)
		g372.students:update{group=g581}
		self.assertEquals(g372.students:count(), 0)
		self.assertEquals(g581.students:count(), 4)
		g581.students:filter{name__in={"Max", "John", "Peter"}}:update{group=g372}
		self.assertEquals(g372.students:count(), 3)
		self.assertEquals(g581.students:count(), 1)

		self.assertTrue(g372.students:delete())
		self.assertEquals(g372.students:count(), 0)
		self.assertEquals(g581.students:count(), 1)
		self.assertTrue(g581.students:delete())
		self.assertEquals(g581.students:count(), 0)

		Student:dropTables()
		Group:dropTables()
	end,
	testT02 = function (self)
		local Article, Category = T02Article, T02Category
		local db = Db.Factory:connect(self.validDsn)
		Article:setDb(db)
		Category:setDb(db)
		Article:dropTables()
		Category:dropTables()
		Article:createTables()
		Category:createTables()
		-- Add categories
		local tech, net = Category:create{title="Tech"}, Category:create{title="Net"}
		self.assertTrue(tech:isKindOf(Category))
		self.assertTrue(net:isKindOf(Category))
		self.assertEquals(tech.title, "Tech")
		self.assertTrue(tech.articles:isEmpty())
		self.assertEquals(net.title, "Net")
		self.assertTrue(net.articles:isEmpty())
		-- Add articles
		-- Throws because categories is required field
		self.assertThrows(function() Article:create{title="A"} end)
		local a = Article:create{title="A", categories={tech}}
		self.assertEquals(a.categories:all()[1], tech)
		local b = Article:create{title="B", categories={tech, net}}
		self.assertEquals(b.categories:count(), 2)
		self.assertEquals(tech.articles:count(), 2)
		self.assertEquals(net.articles:count(), 1)
		a.categories = {net}
		a:save()
		self.assertEquals(tech.articles:count(), 1)
		self.assertEquals(net.articles:count(), 2)
		a.categories = {tech, net}
		a:save()
		self.assertEquals(tech.articles:count(), 2)
		self.assertEquals(net.articles:count(), 2)
		tech.articles = {}
		tech:save()
		self.assertEquals(tech.articles:count(), 0)
		self.assertEquals(net.articles:count(), 2)

		Article:dropTables()
		Category:dropTables()
	end
}
