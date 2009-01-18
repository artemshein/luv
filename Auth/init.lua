local Namespace, Db, Fields = from"Luv":import("Namespace", "Db", "Fields")

module(...)

local GroupRight = Db.Model:extend{
	__tag = .....".GroupRight",
	label = "group right", labelMany = "group rights",
	model = Fields.Char(),
	action = Fields.Char(),
	description = Fields.Char{maxLength = 0}
}

local UserGroup = Db.Model:extend{
	__tag = .....".UserGroup",
	label = "user group", labelMany = "user groups",
	title = Fields.Char{required = true, unique = true},
	description = Fields.Char{maxLength = 0},
	rights = Fields.ManyToMany{references = GroupRight, relatedName="groups"},
}

local User = Db.Model:extend{
	__tag = .....".User",
	label = "user", labelMany = "users",
	login = Fields.Login(),
	name = Fields.Char(),
	passwordHash = Fields.Char{required = true},
	group = Fields.ManyToOne{references=UserGroup}
}

return Namespace:extend{
	__tag = ...,
	ns = ...,
	GroupRight = GroupRight,
	UserGroup = UserGroup,
	User = User
}
