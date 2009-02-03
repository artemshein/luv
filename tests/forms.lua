require"luv.debug"
local io, type, tostring, debug = io, type, tostring, debug
local TestCase, forms, fields, Model, html = require"luv.unittest".TestCase, require"luv.forms", require"luv.fields", require"luv.db.models".Model, require"luv.utils.html"

module(...)

local TestModel = Model:extend{
	title = fields.Char{required=true},
	comments = fields.Int(),
	Meta = {label = "test", labelMany = "tests"}
}

local Form = TestCase:extend{
	__tag = .....".Form",
	testSimple = function (self)
		local F = forms.Form:extend{
			title = fields.Char{required=true},
			comments = fields.Int()
		}
		local f = F()
		self.assertFalse(f:validate())
		f.title = "abc"
		self.assertEquals(f.title, "abc")
		self.assertTrue(f:validate())
	end,
	testModel = function (self)
		local F = forms.ModelForm:extend{
			Meta = {model=TestModel, exclude={"test", "test2"}, fields={"title", "comments"}}
		}
		local f = F()
		self.assertFalse(f:validate())
		f.title = "abc"
		self.assertEquals(f.title, "abc")
		self.assertTrue(f:validate())
	end,
	testInstance = function (self)
		local F = forms.ModelForm:extend{
			Meta = {model=TestModel}
		}
		local t = TestModel{title="abc", comments=25}
		local f = F(t)
		self.assertEquals(f.title, "abc")
		self.assertEquals(f.comments, 25)
	end,
	testWidgets = function (self)
		local F = forms.Form:extend{
			abc = fields.Char{required=true, label="ABC"}
		}
		--io.write(html.escape(F():setAction("/section1/"):setId("form"):asHtml()))
		self.assertEquals(
			F():setAction("/section1/"):setId("form"):asHtml(),
			[[<form id="form" action="/section1/" method="POST"><table><tbody><th><label for="form_abc">ABC</label></th><td><input type="text" name="abc" id="abc" value="" maxlength="255" /></td></tbody></table></form>]]
		)
	end
}

return {
	Form = Form
}
