local getmetatable, io, require = getmetatable, io, require
local table, type, tostring = table, type, tostring
local TestCase, Model, fields, references = require"luv.dev.unittest".TestCase, require"luv.db.models".Model, require"luv.fields", require"luv.fields.references"
local sql, keyvalue = require"luv.db.sql", require"luv.db.keyvalue"

module(...)

-- ManyToOne

local T01Group = Model:extend{
	__tag = .....".T01Group";
	number = fields.Int{pk=true};
	Meta = {label="group";labelMany="groups"};
}

local T01Student = Model:extend{
	__tag = .....".T01Student";
	name = fields.Text{pk=true};
	group = references.ManyToOne{references=T01Group;required=true;relatedName="students"};
	Meta = {label="student";labelMany="students"};
}

-- ManyToMany

local T02Category = Model:extend{
	__tag = .....".T02Category";
	title = fields.Text{required=true};
	Meta = {label="category";labelMany="categories"};
}

local T02Article = Model:extend{
	__tag = .....".T02Article";
	title = fields.Text{required=true};
	categories = references.ManyToMany{references=T02Category;required=true;relatedName="articles"};
	Meta = {label="article";labelMany="articles"};
}

-- OneToOne

local T03Man = Model:extend{
	__tag = .....".T03Man";
	name = fields.Text{pk=true};
	Meta = {label="man";labelMany="men"};
}

local T03Student = Model:extend{
	__tag = .....".T03Student";
	man = references.OneToOne{references=T03Man;pk=true;relatedName="student"};
	group = fields.Int{required=true};
	Meta = {label="student";labelMany="students"};
}
--[[
local T04Man = Model:extend{
	__tag = .....".T01Man",

	name = Char{primaryKey = true},
	friends = ManyToMany"self"
}]]

local Sql = TestCase:extend{
	__tag = .....".Sql";
	_validDsn = "mysql://test:test@localhost/test";
	setUp = function (self)
		Model:db(sql.Factory(self._validDsn))
		--Model:db():logger(function (sql) io.write(sql, "\n") end)
		self.A = Model:extend{
			title = fields.Text{unique=true};
			Meta = {label="a";labelMany="as"};
		}
		self.A:dropTables()
		self.A:createTables()
	end;
	tearDown = function (self)
		self.A:dropTables()
		self.A = nil
	end;
	testAbstract = function (self)
		self.assertThrows(function () Model() end)
	end;
	testBasic = function (self)
		local Test = Model:extend{
			test = fields.Text{minLength=4;maxLength=6};
			Meta = {label="a";labelMany="as"};
		}
		local t = Test()
		t.test = "123"
		self.assertEquals(t.test, "123")
		self.assertEquals(t.test, t:field"test":value())
		self.assertFalse(t:valid())
		t.test = "1234"
		self.assertTrue(t:valid())
	end;
	testFindSimple = function (self)
		local lastId = self.A:db():InsertRow():into(self.A:tableName()):set("?#=?", "title", "abc")()
		self.assertTrue(lastId)
		local a = self.A:find(lastId)
		self.assertEquals(a.id, lastId)
		self.assertEquals(a.title, "abc")
		a = self.A:find{title = "abc"}
		self.assertEquals(a.title, "abc")
		self.assertEquals(a.id, lastId)
	end;
	testInsertSimple = function (self)
		local a = self.A()
		a.title = "testTitle"
		self.assertTrue(a:insert())
		local b = self.A:db():SelectRow():from(self.A:tableName())()
		self.assertEquals(b.title, "testTitle")
		a = self.A()
		a.title = "testTitle"
		self.assertFalse(a:insert())
	end;
	testUpdateSimple = function (self)
		local id = self.A:db():InsertRow():into(self.A:tableName()):set("?#=?", "title", "abc")()
		local a = self.A()
		a.id = id
		a.title = "cde"
		a:update()
		local b = self.A:db():SelectRow():from(self.A:tableName()):where("?#=?n", "id", id)()
		self.assertTrue(b.title, "cde")
	end;
	testQ = function (self)
		self.assertTrue(
			T01Group:all():filter{students__name__in={"John";"Max";"Pete"}}:asSql(),
			"SELECT `group`.* FROM `group` JOIN `student` ON `group`.`number`=`student`.`group` WHERE (`student`.`name` IN ('John', 'Max', 'Pete'));"
		)
		self.assertTrue(
			T01Group:all():filter{students__group__students__name__exact="Vova"}:asSql(),
			"SELECT `group`.* FROM `group` JOIN `student` ON `group`.`number`=`student`.`group` WHERE (`student`.`name`='Vova');"
		)
	end;
	testT01 = function (self)
		local Student, Group = T01Student, T01Group
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
		self.assertEquals(g372.students:all():filter{name__in={"Max";"John";"Mary"}}:count(), 2)
		self.assertEquals(g372.students:exclude"Max":count(), 2)
		self.assertEquals(g372.students:exclude{name__in={"Max";"John";"Fil"}}:count(), 1)
		self.assertEquals(g581.students:count(), 1)
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
	end;
	testT02 = function (self)
		local Article, Category = T02Article, T02Category
		Article:dropTables()
		Category:dropTables()
		Article:createTables()
		Category:createTables()
		-- Add categories
		local tech, net = Category:create{title="Tech"}, Category:create{title="Net"}
		self.assertTrue(tech:isA(Category))
		self.assertTrue(net:isA(Category))
		self.assertEquals(tech.title, "Tech")
		self.assertTrue(tech.articles:empty())
		self.assertEquals(net.title, "Net")
		self.assertTrue(net.articles:empty())
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
	end;
	testT03 = function (self)
		local Man, Student = T03Man, T03Student
		Student:dropTables()
		Man:dropTables()
		Man:createTables()
		Student:createTables()
		--
		local m1 = Man:create{name="John"}
		self.assertTrue(m1:isA(Man))
		self.assertNil(m1.student)
		local s1 = Student:create{man=m1;group=122}
		self.assertTrue(s1:isA(Student))
		self.assertEquals(s1.group, 122)
		self.assertEquals(s1.man.name, "John")
		self.assertEquals(s1.man, m1)
		m1 = Man:find"John"
		self.assertEquals(m1.student, s1)
		--
		m1.student:delete()
		m1 = Man:find"John"
		self.assertNil(m1.student)
		s1 = Student:find(m1)
		self.assertNil(s1)
		Student:dropTables()
		Man:dropTables()
	end;
}

local KeyValue = TestCase:extend{
	__tag = .....".KeyValue";
	_validDsn = "redis://localhost/8";
	setUp = function (self)
		self.A = Model:extend{
			title = fields.Text{unique=true};
			Meta = {label="a";labelMany="as"};
		}
		self.A:db(keyvalue.Factory(self._validDsn))
		self.A:dropTables()
		self.A:createTables()
	end;
	tearDown = function (self)
		self.A:dropTables()
		self.A = nil
	end;
	testAbstract = function (self)
		self.assertThrows(function () Model() end)
	end;
	testBasic = function (self)
		local Test = Model:extend{
			test = fields.Text{minLength=4;maxLength=6};
			Meta = {label="a";labelMany="as"};
		}
		local t = Test()
		t.test = "123"
		self.assertEquals(t.test, "123")
		self.assertEquals(t.test, t:field"test":value())
		self.assertFalse(t:valid())
		t.test = "1234"
		self.assertTrue(t:valid())
	end;
	testFindSimple = function (self)
		local a = self.A:create{title="abc"}
		a = self.A:find(a.pk)
		self.assertEquals(a.title, "abc")
		a = self.A:find{title="abc"}
		self.assertEquals(a.title, "abc")
	end;
	--[[testT01 = function (self)
		local Student, Group = T01Student, T01Group
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
		self.assertEquals(g372.students:all():filter{name__in={"Max";"John";"Mary"}}:count(), 2)
		self.assertEquals(g372.students:exclude"Max":count(), 2)
		self.assertEquals(g372.students:exclude{name__in={"Max";"John";"Fil"}}:count(), 1)
		self.assertEquals(g581.students:count(), 1)
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
	end;]]
	--[[testT02 = function (self)
		local Article, Category = T02Article, T02Category
		Article:dropTables()
		Category:dropTables()
		Article:createTables()
		Category:createTables()
		-- Add categories
		local tech, net = Category:create{title="Tech"}, Category:create{title="Net"}
		self.assertTrue(tech:isA(Category))
		self.assertTrue(net:isA(Category))
		self.assertEquals(tech.title, "Tech")
		self.assertTrue(tech.articles:empty())
		self.assertEquals(net.title, "Net")
		self.assertTrue(net.articles:empty())
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
	end;]]
	testT03 = function (self)
		local Man, Student = T03Man, T03Student
		Student:dropTables()
		Man:dropTables()
		Man:createTables()
		Student:createTables()
		--
		local m1 = Man:create{name="John"}
		self.assertTrue(m1:isA(Man))
		self.assertNil(m1.student)
		local s1 = Student:create{man=m1;group=122}
		self.assertTrue(s1:isA(Student))
		self.assertEquals(s1.group, 122)
		self.assertEquals(s1.man.name, "John")
		self.assertEquals(s1.man, m1)
		m1 = Man:find"John"
		self.assertEquals(m1.student, s1)
		--
		m1.student:delete()
		m1 = Man:find"John"
		self.assertNil(m1.student)
		s1 = Student:find(m1)
		self.assertNil(s1)
		Student:dropTables()
		Man:dropTables()
	end;
}

return {Sql=Sql;KeyValue=KeyValue}
