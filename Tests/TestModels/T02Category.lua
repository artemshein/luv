local Model, Char, ManyToMany = require"Models.Model", require"Fields.Char", require"Fields.ManyToMany"

module(...)

return Model:extend{
	__tag = "Tests.TestModels.T02Category",

	title = Char:new{required=true},
	articles = ManyToMany:new"Tests.TestModels.T02Article"
}
