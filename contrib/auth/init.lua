local models, fields, references, forms = require "luv.db.models", require "luv.fields", require "luv.fields.references", require "luv.forms"

module(...)

local GroupRight = models.Model:extend{
	__tag = .....".GroupRight",
	Meta = {label="group right", labelMany="group rights"},
	model = fields.Char(),
	action = fields.Char(),
	description = fields.Char{maxLength = 0}
}

local UserGroup = models.Model:extend{
	__tag = .....".UserGroup",
	Meta = {label="user group", labelMany="user groups"},
	title = fields.Char{required=true, unique=true},
	description = fields.Char{maxLength=0},
	rights = references.ManyToMany{references=GroupRight, relatedName="groups"},
}

local User = models.Model:extend{
	__tag = .....".User",
	Meta = {label="user", labelMany="users"},
	login = fields.Login{label="login"},
	name = fields.Char(),
	passwordHash = fields.Char{required = true},
	group = references.ManyToOne{references=UserGroup, relatedName="users"}
}

local LoginForm = forms.Form:extend{
	__tag = .....".LoginForm",
	login = User:getField "login",
	password = fields.Char{label="password", maxLength=32, minLength=6},
	ok = fields.Submit{defaultValue="Authorise"}
}

return {
	models = {
		GroupRight = GroupRight,
		UserGroup = UserGroup,
		User = User
	},
	forms = {
		LoginForm = LoginForm
	}
}
