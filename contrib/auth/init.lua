local string = require "luv.string"
local io, type, require, math, tostring = io, type, require, math, tostring
local ipairs = ipairs
local tr = tr
local models, fields, references, forms, managers, crypt, widgets = require "luv.db.models", require "luv.fields", require "luv.fields.references", require "luv.forms", require "luv.managers", require "luv.crypt", require "luv.fields.widgets"
local widgets = require "luv.fields.widgets"
local Exception = require "luv.exceptions".Exception
local capitalize = string.capitalize

module(...)

local MODULE = (...)
local property = models.Model.property

local GroupRight = models.Model:extend{
	__tag = .....".GroupRight",
	Meta = {labels={"group right";"group rights"}},
	model = fields.Text{required=true;minLength=1};
	action = fields.Text{required=true;minLength=1};
	description = fields.Text{maxLength=false};
	__tostring = function (self) return tostring(self.model)..": "..tostring(self.action) end;
	superuserRight = function (self) return self._superuserRight end;
}

GroupRight.superuserRight = GroupRight{model="any model";action="any action"}

local UserGroup = models.Model:extend{
	__tag = .....".UserGroup",
	Meta = {labels={"user group";"user groups"}},
	title = fields.Text{required=true;unique=true},
	description = fields.Text{maxLength=false},
	rights = references.ManyToMany{references=GroupRight;relatedName="groups"},
	__tostring = function (self) return tostring(self.title) end;
	hasRight = function (self, model, action)
		local superuserRight = GroupRight:superuserRight()
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
	Meta = {labels={"user";"users"}};
	_sessId = "LUV_AUTH";
	sessId = property"string";
	secretSalt = property"string";
	-- Fields
	isActive = fields.Boolean{defaultValue=true;label=tr"active user"};
	login = fields.Login();
	name = fields.Text();
	email = fields.Email();
	passwordHash = fields.Text{required=true};
	group = references.ManyToOne{references=UserGroup;relatedName="users"};
	__tostring = function (self) return tostring(self.name) end;
	-- Methods
	encodePassword = function (self, password, method, salt)
		if not password then Exception "Empty password is restricted!" end
		method = method or "sha1"
		if not salt then
			salt = tostring(crypt.hash(method, math.random(2000000000)))
			salt = string.slice(salt, math.random(10), math.random(5, string.len(salt)-10))
		end
		return method.."$"..salt.."$"..tostring(crypt.hash(method, password..salt..(self:secretSalt() or "")))
	end;
	comparePassword = function (self, password)
		local method, salt, hash = string.split(self.passwordHash, "$", "$")
		return self:encodePassword(password, method, salt) == self.passwordHash
	end;
	authUser = function (self, session, loginForm)
		if self._authUser then return self._authUser end
		local sessId = self:sessId()
		if not loginForm or "table" ~= type(loginForm) or not loginForm.isA
			or not loginForm:isA(require(MODULE).forms.Login) or not loginForm:submitted() or not loginForm:valid() then
			if not session[sessId] then
				session[sessId] = nil
				session:save()
				self._authUser = nil
				return nil
			end
			local user = self:find(session[sessId].user)
			if not user then
				session[sessId] = nil
				session:save()
			end
			self._authUser = user
			return user
		end
		local user = self:find{login=loginForm.login}
		if not user or not user:comparePassword(loginForm.password) then
			session[sessId] = nil
			session:save()
			loginForm:addError(tr"Invalid authorisation data.")
			return nil
		end
		session[sessId] = {user=user.pk}
		session:save()
		self._authUser = user
		return user
	end;
	logout = function (self, session)
		session[self:sessId()] = nil
		session:save()
	end;
	-- Rights
	hasRight = function (self, model, action)
		return self.group and self.group:hasRight(model, right)
	end;
	rightToCreate = function (self, model)
		if "string" ~= type(model) then
			model = model:label()
		end
		return GroupRight{model=model;action="create";description="Right to create "..model}
	end;
	rightToEdit = function (self, model)
		if "string" ~= type(model) then
			model = model:label()
		end
		return GroupRight{model=model;action="edit";description="Right to edit "..model}
	end;
	rightToDelete = function (self, model)
		if "string" ~= type(model) then
			model = model:label()
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

local Login = forms.Form:extend{
	__tag = .....".Login",
	Meta = {fields={"login";"password";"authorise"}};
	login = User:field"login",
	password = fields.Password{required=true};
	authorise = fields.Submit{defaultValue=capitalize(tr"log in")}
}

local _modelsAdmins
local modelsAdmins = function ()
	if not _modelsAdmins then
		local ModelAdmin = require "luv.contrib.admin".ModelAdmin
		_modelsAdmins = {
			ModelAdmin:extend{
				__tag = MODULE..".GroupRightAdmin";
				_model = GroupRight;
				_category = "authorisation";
				_smallIcon = {path="/images/icons/auth/user_accept16.png";width=16;height=16};
				_bigIcon = {path="/images/icons/auth/user_accept48.png";width=48;height=48};
				_displayList = {"model";"action"};
				_fields = {"id";"model";"action";"description"};
			};
			ModelAdmin:extend{
				__tag = MODULE..".UserGroupAdmin";
				_model = UserGroup;
				_category = "authorisation";
				_smallIcon = {path="/images/icons/auth/users16.png";width=16;height=16};
				_bigIcon = {path="/images/icons/auth/users48.png";width=48;width=48};
				_displayList = {"title"};
				_fields = {"id";"title";"description";"rights"};
			};
			ModelAdmin:extend{
				__tag = MODULE..".UserAdmin";
				_model = User;
				_category = "authorisation";
				_smallIcon = {path="/images/icons/auth/community_users16.png";width=16;height=16};
				_bigIcon = {path="/images/icons/auth/community_users48.png";width=48;height=48};
				_displayList = {"login";"name";"group"};
				_form = forms.ModelForm:extend{
					Meta = {model = User;fields={"id";"login";"password";"password2";"name";"group";"isActive"}};
					id = User:field "id":clone();
					login = User:field "login":clone();
					name = User:field "name":clone();
					password = fields.Text{minLength=6;maxLength=32;widget=widgets.PasswordInput};
					password2 = fields.Text{minLength=6;maxLength=32;label="repeat password";widget=widgets.PasswordInput};
					group = fields.ModelSelect(UserGroup:all():value());
					isActive = User:field "isActive":clone();
					isValid = function (self)
						if not forms.Form.valid(self) then
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
				initModel = function (self, model, form)
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
	return _modelsAdmins
end

return {
	models = {
		GroupRight = GroupRight;
		UserGroup = UserGroup;
		User = User;
	};
	forms = {
		Login = Login;
	};
	modelsAdmins = modelsAdmins;
}
