local Model, Char, ManyToMany = require"Models.Model", require"Fields.Char", require"Fields.ManyToMany"

module(...)

return Model:extend{
	__tag = "Models.GroupRight",

	model = Char(),
	action = Char(),
	description = Char{maxLength = 0},
	groups = ManyToMany"Models.UserGroup"
}
