require "luv.debug"
local io, type, require, math, tostring, string, debug = io, type, require, math, tostring, string, debug
local models, fields, references, forms, managers, crypt, widgets = require "luv.db.models", require "luv.fields", require "luv.fields.references", require "luv.forms", require "luv.managers", require "luv.crypt", require "luv.fields.widgets"

module(...)

local MODULE = ...

local GroupRight = models.Model:extend{
	__tag = .....".GroupRight",
	Meta = {labels={"group right";"group rights"}},
	model = fields.Text{required=true;minLength=1};
	action = fields.Text{required=true;minLength=1};
	description = fields.Text{maxLength=false};
	__tostring = function (self) return tostring(self.model)..": "..tostring(self.action) end;
}

local UserGroup = models.Model:extend{
	__tag = .....".UserGroup",
	Meta = {labels={"user group";"user groups"}},
	title = fields.Text{required=true, unique=true},
	description = fields.Text{maxLength=false},
	rights = references.ManyToMany{references=GroupRight;relatedName="groups"},
	__tostring = function (self) return tostring(self.title) end;
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
	end
}

local LoginForm = forms.Form:extend{
	__tag = .....".LoginForm",
	Meta = {fields={"login";"password";"authorise"}};
	login = User:getField "login",
	password = fields.Text{label="password", maxLength=32, minLength=6, widget=widgets.PasswordInput},
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
					Meta = {fields={"id";"login";"password";"password2";"name";"group"}};
					id = fields.Id();
					login = fields.Login();
					name = fields.Text();
					password = fields.Text{minLength=6;maxLength=32};
					password2 = fields.Text{minLength=6;maxLength=32;label="Repeat password"};
					group = forms.fields.ModelSelect(UserGroup:all():getValue());
				};
				initModelByForm = function (self, model, form)
					model.id = form.id
					model.login = form.login
					model.name = form.name
					model.group = form.group
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
