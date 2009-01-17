local Model, Login, Char, ForeignKey = require"Models.Model", require"Fields.Login", require"Fields.Char", require"Fields.ManyToOne"

module(...)

return Model:extend{
	__tag = "Models.User",

	login = Login(),
	name = Char(),
	passwordHash = Char{required = true},
	group = ForeignKey{references = "Models.UserGroup"}
}
