local Model, Char, OneToMany, ManyToMany = require"Models.Model", require"Fields.Char", require"Fields.OneToMany", require"Fields.ManyToMany"

module(...)

return Model:extend{
	__tag = "Models.UserGroup",

	init = function (self)
		self:setFields{
			title = Char:new{required = true, unique = true},
			description = Char:new{maxLength = 0},
			rights = ManyToMany:new{references = "Models.GroupRight"},
			users = OneToMany:new"Models.User",
		}
	end
}
