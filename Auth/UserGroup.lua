local Model, Char, OneToMany, ManyToMany = require"Models.Model", require"Fields.Char", require"Fields.OneToMany", require"Fields.ManyToMany"

module(...)

return Model:extend{
	__tag = "Models.UserGroup",

	title = Char{required = true, unique = true},
	description = Char{maxLength = 0},
	rights = ManyToMany{references = "Models.GroupRight"},
	users = OneToMany"Models.User"
}
