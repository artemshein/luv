local io, type, tostring, require = io, type, tostring, require
local TestCase, forms, fields, Model, html = require "luv.dev.unittest".TestCase, require "luv.forms", require "luv.fields", require "luv.db.models".Model, require "luv.utils.html"
local references = require "luv.fields.references"

module(...)

local TestModel = Model:extend{
	title = fields.Text{required=true},
	comments = fields.Int(),
	Meta = {label = "test", labelMany = "tests"}
}

local Form = TestCase:extend{
	__tag = .....".Form",
	testSimple = function (self)
		local F = forms.Form:extend{
			Meta = {fields = {"title", "comments"}},
			title = fields.Text{required=true},
			comments = fields.Int()
		}
		local f = F()
		self.assertFalse(f:valid())
		f.title = "abc"
		self.assertEquals(f.title, "abc")
		self.assertTrue(f:valid())
	end,
	testModel = function (self)
		local F = forms.ModelForm:extend{
			Meta = {model=TestModel;exclude={"test", "test2"};fields={"title", "comments"}}
		}
		local f = F()
		self.assertFalse(f:valid())
		f.title = "abc"
		self.assertEquals(f.title, "abc")
		self.assertTrue(f:valid())
	end,
	testInstance = function (self)
		local F = forms.ModelForm:extend{
			Meta = {model=TestModel;fields={"title", "comments"}}
		}
		local t = TestModel{title="abc", comments=25}
		local f = F(t)
		self.assertEquals(f.title, "abc")
		self.assertEquals(f.comments, 25)
	end
}

local Category = Model:extend{
	__tag = .....".Category";
	Meta = {labels={"category";"categories"}};
	title = fields.Text();
}

local Article = Model:extend{
	__tag = .....".Article";
	Meta = {labels={"article";"articles"}};
	title = fields.Text{required=true};
	categories = references.ManyToMany{references=Category;required=true;relatedName="articles"};
}

local ModelForm = TestCase:extend{
	__tag = .....".ModelForm";
	setUp = function (self)
		self:tearDown()
		Category:createTables()
		Article:createTables()
	end;
	tearDown = function (self)
		Article:dropTables()
		Category:dropTables()
	end;
	testSimple = function (self)

		Category:create{title="net"}
		Category:create{title="web"}
		Category:create{title="microsoft"}

		local Form = forms.ModelForm:extend{Meta={model=Article}}
		local f = Form():addField("add", fields.Submit "Add")
		self.assertFalse(f:submitted())
		self.assertFalse(f:valid())

		f:values{title="one"}
		self.assertFalse(f:submitted())
		self.assertFalse(f:valid())

		f:values{title="one";categories=Category:all():filter{title__in={"net";"web"}}:value()}
		self.assertFalse(f:submitted())
		self.assertTrue(f:valid())

		f:values{title="one";categories=Category:all():filter{title__in={"net";"web"}}:value();add="Add"}
		self.assertTrue(f:submitted())
		self.assertTrue(f:valid())

		local article = Article(f:values())
		article:save()
		self.assertEquals(article.categories:count(), 2)
	end;
}

return {
	Form=Form;ModelForm=ModelForm;
}
