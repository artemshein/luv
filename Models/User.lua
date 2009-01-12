local Model, Login, Char, ForeignKey = require"Models.Model", require"Fields.Login", require"Fields.Char", require"Fields.ManyToOne"

module(...)

return Model:extend{
	__tag = "Models.User",

	login = Login:new(),
	name = Char:new(),
	passwordHash = Char:new{required = true},
	group = ForeignKey:new{references = "Models.UserGroup"}
}
