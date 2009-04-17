require "luv.debug"
local io, type, require, math, tostring, string, debug = io, type, require, math, tostring, string, debug
local ipairs = ipairs
local models, fields, references, forms, managers, crypt, widgets = require "luv.db.models", require "luv.fields", require "luv.fields.references", require "luv.forms", require "luv.managers", require "luv.crypt", require "luv.fields.widgets"
local widgets = require "luv.fields.widgets"

module(...)

local MODULE = ...

local GroupRight = models.Model:extend{
	__tag = .....".GroupRight",
	Meta = {labels={"group right";"group rights"}},
	model = fields.Text{required=true;minLength=1};
	action = fields.Text{required=true;minLength=1};
	description = fields.Text{maxLength=false};
	__tostring = function (self) return tostring(self.model)..": "..tostring(self.action) end;
	getSuperuserRight = function (self) return self.superuserRight end;
}

GroupRight.superuserRight = GroupRight{model="any model";action="any action"}

local UserGroup = models.Model:extend{
	__tag = .....".UserGroup",
	Meta = {labels={"user group";"user groups"}},
	title = fields.Text{required=true, unique=true},
	description = fields.Text{maxLength=false},
	rights = references.ManyToMany{references=GroupRight;relatedName="groups"},
	__tostring = function (self) return tostring(self.title) end;
	hasRight = function (self, model, action)
		local superuserRight = GroupRight:getSuperuserRight()
		for _, v in ipairs(self.rights:getValue()) do
			if (v.model == superuserRight.model and v.action == superuserRight.action)
			or (v.model == model and v.action == action) then
				return true
			end
		end
		return false
	end;
}

local User = models.Model:extend{
	__tag = .....".User",
	Meta = {labels={"user", "users"}};
	sessId = "LUV_AUTH",
	secretSalt = "",
	-- Fields
	isActive = fields.Boolean{defaultValue=true;label="active user"};
	login = fields.Login(),
	name = fields.Text(),
	passwordHash = fields.Text{required = true},
	group = references.ManyToOne{references=UserGroup, relatedName="users"},
	__tostring = function (self) return tostring(self.name) end;
	-- Methods
	getSecretSalt = function (self) return self.secretSalt end,
	setSecretSalt = function (self, secretSalt) self.secretSalt = secretSalt return self end,
	encodePassword = function (self, password, method, salt)
		if not password then Exception "Empty password is restricted!":throw() end
		method = method or "sha1"
		if not salt then
			salt = tostring(crypt.hash(method, math.random(2000000000)))
			salt = string.slice(salt, math.random(10), math.random(5, string.len(salt)-10))
		end
		return method.."$"..salt.."$"..tostring(crypt.hash(method, password..salt..self.secretSalt))
	end,
	comparePassword = function (self, password)
		local method, salt, hash = string.split(self.passwordHash, "$", "$")
		return self:encodePassword(password, method, salt) == self.passwordHash
	end,
	getAuthUser = function (self, session, loginForm)
		if self.authUser then return self.authUser end
		if not loginForm or "table" ~= type(loginForm) or not loginForm.isObject
			or not loginForm:isKindOf(require(MODULE).forms.LoginForm) or not loginForm:isSubmitted() or not loginForm:isValid() then
			if not session[self.sessId] then
				session[self.sessId] = nil
				session:save()
				self.authUser = nil
				return nil
			end
			local user = self:find(session[self.sessId].user)
			self.authUser = user
			return user
		end
		local user = self:find{login=loginForm.login}
		if not user or not user:comparePassword(loginForm.password) then
			session[self.sessId] = nil
			session:save()
			loginForm:addError "Invalid authorisation data."
			return nil
		end
		session[self.sessId] = {user=user.pk}
		session:save()
		self.authUser = user
		return user
	end,
	logout = function (self, session)
		session[self.sessId] = nil
		session:save()
	end;
	-- Rights
	hasRight = function (self, model, action)
		return self.group and self.group:hasRight(model, right)
	end;
	rightToCreate = function (self, model)
		if "string" ~= type(model) then
			model = model:getLabel()
		end
		return GroupRight{model=model;action="create";description="Right to create "..model}
	end;
	rightToEdit = function (self, model)
		if "string" ~= type(model) then
			model = model:getLabel()
		end
		return GroupRight{model=model;action="edit";description="Right to edit "..model}
	end;
	rightToDelete = function (self, model)
		if "string" ~= type(model) then
			model = model:getLabel()
		end
		return GroupRight{model=model;action="delete";description="Right to delete "..model}
	end;
	canCreate = function (self, model)
		local right = self:rightToCreate(model)
		return self:hasRight(right.model, right.action)
	end;
	canEdit = function (self, model)
		local right = self:rightToEdit(model)
		return self:hasRight(right.model, right.action)
	end;
	canDelete = function (self, model)
		local right = self:rightToDelete(model)
		return self:hasRight(right.model, right.action)
	end;
}

local LoginForm = forms.Form:extend{
	__tag = .....".LoginForm",
	Meta = {fields={"login";"password";"authorise"}};
	login = User:getField "login",
	password = fields.Text{label="password";maxLength=32;minLength=6;widget=widgets.PasswordInput;required=true};
	authorise = fields.Submit{defaultValue="Authorise"}
}

local modelsAdmins
local getModelsAdmins = function ()
	if not modelsAdmins then
		local ModelAdmin = require "luv.contrib.admin".ModelAdmin
		modelsAdmins = {
			ModelAdmin:extend{
				__tag = MODULE..".GroupRightAdmin";
				model = GroupRight;
				category = "authorisation";
				smallIcon = {path="/images/icons/auth/user_accept16.png";width=16;height=16};
				bigIcon = {path="/images/icons/auth/user_accept48.png";width=48;height=48};
				displayList = {"model";"action"};
				fields = {"id";"model";"action";"description"};
			};
			ModelAdmin:extend{
				__tag = MODULE..".UserGroupAdmin";
				model = UserGroup;
				category = "authorisation";
				smallIcon = {path="/images/icons/auth/users16.png";width=16;height=16};
				bigIcon = {path="/images/icons/auth/users48.png";width=48;width=48};
				displayList = {"title"};
				fields = {"id";"title";"description";"rights"};
			};
			ModelAdmin:extend{
				__tag = MODULE..".UserAdmin";
				model = User;
				category = "authorisation";
				smallIcon = {path="/images/icons/auth/community_users16.png";width=16;height=16};
				bigIcon = {path="/images/icons/auth/community_users48.png";width=48;height=48};
				displayList = {"login";"name";"group"};
				form = forms.Form:extend{
					Meta = {fields={"id";"login";"password";"password2";"name";"group";"isActive"}};
					id = User:getField "id":clone();
					login = User:getField "login":clone();
					name = User:getField "name":clone();
					password = fields.Text{minLength=6;maxLength=32;widget=widgets.PasswordInput};
					password2 = fields.Text{minLength=6;maxLength=32;label="Repeat password";widget=widgets.PasswordInput};
					group = fields.ModelSelect(UserGroup:all():getValue());
					isActive = User:getField "isActive":clone();
					isValid = function (self)
						if not forms.Form.isValid(self) then
							return false
						end
						if self.password then
							if self.password ~= self.password2 then
								self:addError "Entered passwords don't match."
								return false
							end
						end
						return true
					end;
				};
				initModelByForm = function (self, model, form)
					model.id = form.id
					model.login = form.login
					model.name = form.name
					model.group = form.group
					model.isActive = form.isActive
					if form.password then
						model.passwordHash = model:encodePassword(form.password)
					end
				end;
			};
		}
	end
	return modelsAdmins
end

return {
	models = {
		GroupRight = GroupRight,
		UserGroup = UserGroup,
		User = User
	},
	forms = {
		LoginForm = LoginForm
	};
	getModelsAdmins = getModelsAdmins;
}
