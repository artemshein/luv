require "luv.string"
local io, ipairs, tostring, pairs, table, tonumber, string = io, ipairs, tostring, pairs, table, tonumber, string
local debug, unpack, type, rawget, select = debug, unpack, type, rawget, select
local Object, auth, models, html = require "luv.oop".Object, require "luv.contrib.auth", require "luv.db.models", require "luv.utils.html"
local fields = require "luv.fields"
local forms = require "luv.forms"
local json = require "luv.utils.json"

module(...)

local ModelAdmin = Object:extend{
	__tag = .....".ModelAdmin";
	getModel = function (self) return self.model end;
	setModel = function (self, model) self.model = model return self end;
	getSmallIcon = function (self) return self.smallIcon end;
	setSmallIcon = function (self, icon) self.smallIcon = icon return self end;
	getBigIcon = function (self) return self.bigIcon end;
	setBigIcon = function (self, icon) self.bigIcon = icon return self end;
	getCategory = function (self) return self.category end;
	setCategory = function (self, category) self.category = category return self end;
	getPath = function (self) return self.path or string.replace(string.lower(self:getModel():getLabelMany()), " ", "_") end;
	getFields = function (self) return self.fields end;
	getDisplayList = function (self)
		if self.displayList then
			return self.displayList
		end
		local res, name, field = {}
		for name, _ in pairs(self:getModel():getFieldsByName()) do
			table.insert(res, name)
		end
		return res
	end;
	getForm = function (self)
		if not self.form then
			self.form = forms.ModelForm:extend{Meta={id="form";model=self:getModel();fields=self:getFields()}}
		end
		return self.form
	end;
	initModelByForm = function (self, model, form) model:setValues(form:getValues()) return self end;
	initFormByModel = function (self, form, model) form:setValues(model:getValues()) return self end;
}

local UserMsgsStack = Object:extend{
	__tag = .....".UserMsgsStack";
	init = function (self) self.msgs = {} end;
	okMsg = function (self, msg)
		table.insert(self.msgs, {msg=msg;status="ok"})
		return self
	end;
	errorMsg = function (self, msg)
		table.insert(self.msgs, {msg=msg;status="error"})
		return self
	end;
	getMsgs = function (self) return self.msgs end;
}

local AdminSite = Object:extend{
	__tag = .....".AdminSite";
	init = function (self, luv, ...)
		self.luv = luv
		modelsList = modelsList or models.Model.modelsList or {}
		local modelsCategories, _, model, i = {}
		for i = 1, select("#", ...) do
			modelsList = select(i, ...)
			for _, model in ipairs(modelsList) do
				local category, admin
				if "table" == type(model) and model.isObject and model:isKindOf(models.Model) then
					admin = ModelAdmin:extend{model=model}
				else
					admin = model
				end
				category = admin:getCategory() or "not categorised"
				modelsCategories[category] = modelsCategories[category] or {}
				table.insert(modelsCategories[category], admin)
			end
		end
		self.modelsCategories = modelsCategories
	end;
	findAdmin = function (self, path)
		local category, admins, admin
		for category, admins in pairs(self.modelsCategories) do
			for _, admin in ipairs(admins) do
				if admin:getPath() == path then return admin end
			end
		end
		return false
	end;
	getUrls = function (self)
		local luv = self.luv
		return {
			{"^/login$"; function (urlConf)
				local form = auth.forms.LoginForm(luv:getPostData())
				local user = auth.models.User:getAuthUser(luv:getSession(), form)
				if user and user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri()):sendHeaders() end
				luv:assign{
					capitalize=string.capitalize;title="Authorisation";
					ipairs=ipairs;tostring=tostring;form=form;user=user;
				}
				luv:display "admin/login.html"
			end};
			{"^/logout$"; function (urlConf)
				auth.models.User:logout(luv:getSession())
				luv:setResponseHeader("Location", "/"):sendHeaders()
			end};
			{"^/([^/]+)/add$"; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then return false end
				local model = admin:getModel()
				local form = admin:getForm():addField("add", fields.Submit "Add")(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted("add") and form:isValid() then
					local record = model()
					admin:initModelByForm(record, form)
					if record:save() then
						msgsStack:okMsg(string.capitalize(model:getLabel()).." was added successfully!")
						form:setValues{}
					else
						msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not added!")
					end
				end
				luv:debug(luv:getPostData())
				luv:debug(form:getErrors())
				luv:assign{
					ipairs=ipairs;capitalize=string.capitalize;
					tostring=tostring;html=html;
					user=user;model=model;urlConf=urlConf;
					title="Add "..model:getLabel();
					form=form;userMsgs=msgsStack:getMsgs();
				}
				luv:display "admin/add.html"
			end};
			{"^/([^/]+)/records$"; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then return false end
				local model = admin:getModel()
				if model:isKindOf(models.TreeModel) then
					luv:assign{
						pairs=pairs;ipairs=ipairs;tostring=tostring;
						nodes={model:findRoot()};
						isRoot=true;
					}
					luv:display "admin/_records-tree.html"
				else
					local page = tonumber(luv:getPost "page") or 1
					luv:assign{
						pairs=pairs;ipairs=ipairs;capitalize=string.capitalize;
						tostring=tostring;html=html;urlConf=urlConf;
						user=user;model=model;page=page;
						fields=admin:getDisplayList();
						p=models.Paginator(model, 10);
						title=string.capitalize(model:getLabelMany());
					}
					luv:display "admin/_records-table.html"
				end
			end};
			{"^/([^/]+)/([^/]+)"; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then return false end
				local model = admin:getModel()
				local record = model:find(urlConf:getCapture(2))
				if not record then return false end
				local form = admin:getForm():addField("save", fields.Submit "Save")(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted("save") then
					if form:isValid() then
						admin:initModelByForm(record, form)
						if record:save() then
							msgsStack:okMsg(string.capitalize(model:getLabel()).." was saved successfully!")
						else
							msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not saved!")
						end
					end
				else
					admin:initFormByModel(form, record)
				end
				luv:assign{
					ipairs=ipairs;capitalize=string.capitalize;
					tostring=tostring;html=html;
					user=user;model=model;urlConf=urlConf;
					title="Edit "..model:getLabel();
					form=form;userMsgs=msgsStack:getMsgs();
				}
				luv:display "admin/edit.html"
			end};
			{"^/([^/]+)$"; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then return false end
				local model = admin:getModel()
				luv:assign{
					capitalize=string.capitalize;
					tostring=tostring;
					user=user;
					model=model;
					urlConf=urlConf;
					title=string.capitalize(model:getLabelMany());
				}
				luv:display "admin/records.html"
			end};
			{"^$"; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
				luv:assign{
					pairs=pairs;ipairs=ipairs;
					tostring=tostring;
					urlConf=urlConf;
					user=user;
					capitalize=string.capitalize;lower=string.lower;replace=string.replace;
					title="AdminSite";
					categories=self.modelsCategories;
				}
				luv:display "admin/main.html"
			end};
		}
	end;
}

return {ModelAdmin=ModelAdmin;AdminSite=AdminSite}
