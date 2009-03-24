local forms, fields, references = require "luv.forms", require "luv.fields", require "luv.fields.references"
local ModelAdmin = require "luv.contrib.admin".ModelAdmin
local models = require "luv.contrib.auth".models

module(...)

local GroupRightAdmin = ModelAdmin:extend{
	__tag = .....".GroupRightAdmin";
	category = "authorisation";
	smallIcon = {path="/images/icons/auth/user_accept16.png";width=16;height=16};
	bigIcon = {path="/images/icons/auth/user_accept48.png";width=48;height=48};
	displayList = {"model", "action"};
}

local UserGroupAdmin = ModelAdmin:extend{
	__tag = .....".UserGroupAdmin";
	category = "authorisation";
	smallIcon = {path="/images/icons/auth/users16.png";width=16;height=16};
	bigIcon = {path="/images/icons/auth/users48.png";width=48;width=48};
	displayList = {"title"};
}

local UserAdmin = ModelAdmin:extend{
	__tag = .....".UserAdmin";
	category = "authorisation";
	smallIcon = {path="/images/icons/auth/community_users16.png";width=16;height=16};
	bigIcon = {path="/images/icons/auth/community_users48.png";width=48;height=48};
	displayList = {"login", "name", "group"};
	form = forms.Form:extend{
		login = fields.Login();
		name = fields.Text();
		password = fields.Text{minLength=6;maxLength=32};
		password2 = fields.Text{minLength=6;maxLength=32};
		group = references.ManyToOne{references=models.UserGroup};
	};
}

return {{models.GroupRight;GroupRightAdmin};{models.UserGroup;UserGroupAdmin};{models.User;UserAdmin}}
