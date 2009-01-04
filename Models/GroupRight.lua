local Model, Char, ManyToMany = require"Models.Model", require"Fields.Char", require"Fields.ManyToMany"

module(...)

return Model:extend{
	__tag = "Models.GroupRight",

	fields = {
		model = Char:new(),
		action = Char:new(),
		description = Char:new{maxLength = 0},
		groups = ManyToMany:new"Models.UserGroup"
	}
}
