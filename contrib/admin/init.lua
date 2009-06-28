local string = require "luv.string"
local tr = tr
local io, ipairs, tostring, pairs, table, tonumber = io, ipairs, tostring, pairs, table, tonumber
local unpack, type, rawget, select = unpack, type, rawget, select
local os = os
local Object, auth, models, html = require "luv.oop".Object, require "luv.contrib.auth", require "luv.db.models", require "luv.utils.html"
local getObjectOr404 = require "luv".getObjectOr404
local fields = require "luv.fields"
local forms = require "luv.forms"
local json = require "luv.utils.json"
local references = require "luv.fields.references"
local ws = require "luv.webservers"

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
		local res, field = {}
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
	isTree = function (self) return self:getModel():isKindOf(models.Tree) end;
}

local ActionLog = models.Model:extend{
	__tag = .....".ActionLog";
	Meta = {labels={"action log";"action logs"}};
	datetime = fields.Datetime{autoNow=true;label="date and time";required=true};
	user = references.ManyToOne{references=auth.models.User;required=true;relatedName="actionLogs"};
	type = fields.Text{required=true};
	message = fields.Text{maxLength=false;required=true};
	__tostring = function (self) return tostring(self.message) end;
	logCreate = function (self, baseUri, user, admin, record)
		self:create{user=user;type=(tr "creating");message="Created "..record:getLabel().." "..[[<a href="]]..baseUri.."/"..admin:getPath().."/"..tostring(record.pk)..[[">]]..tostring(record).."</a> by "..tostring(user).."."}
	end;
	logSave = function (self, baseUri, user, admin, record)
		self:create{user=user;type=(tr "changing");message="Edited "..record:getLabel().." "..[[<a href="]]..baseUri.."/"..admin:getPath().."/"..tostring(record.pk)..[[">]]..tostring(record).."</a> by "..tostring(user).."."}
	end;
	logDelete = function (self, baseUri, user, admin, record)
		self:create{user=user;type=(tr "deleting");message="Deleted "..record:getLabel().." "..tostring(record).." by "..tostring(user).."."}
	end;
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
		local modelsList = {}
		local modelsCategories = {}
		for i = 1, select("#", ...) do
			modelsList = select(i, ...)
			for _, model in ipairs(modelsList) do
				local category, admin
				if "table" == type(model) and model.isKindOf and model:isKindOf(models.Model) then
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
		for category, admins in pairs(self.modelsCategories) do
			for _, admin in ipairs(admins) do
				if admin:getPath() == path then return admin end
			end
		end
		return false
	end;
	getUrls = function (self)
		local luv = self.luv
		luv:debug(luv:getPostData())
		local function getUser (urlConf)
			local user = auth.models.User:getAuthUser(luv:getSession())
			if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
			return user
		end
		return {
			{"^/login$"; function (urlConf)
				local form = auth.forms.Login(luv:getPostData())
				local user = auth.models.User:getAuthUser(luv:getSession(), form)
				if user and user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri()):sendHeaders() end
				luv:assign{
					capitalize=string.capitalize;title="authorisation";
					ipairs=ipairs;tostring=tostring;form=form;user=user;
				}
				luv:display "admin/login.html"
			end};
			{"^/logout$"; function (urlConf)
				auth.models.User:logout(luv:getSession())
				luv:setResponseHeader("Location", "/"):sendHeaders()
			end};
			{"^/([^/]+)/create/?$"; function (urlConf, modelName)
				local user = getUser(urlConf)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:getModel()
				if not user:canCreate(model) then ws.Http403() end
				local form = admin:getForm():addField("create", fields.Submit(string.capitalize(tr "create")))(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted("create") and form:isValid() then
					if model:isKindOf(models.Tree) then
						if model:findRoot() then
							msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not created!")
							form:addError "Root record already exist."
						else
							local record = model()
							record.left = 1
							record.right = 2
							form:initModel(record)
							if record:save() then
								ActionLog:logCreate(urlConf:getBaseUri(), user, admin, record)
								msgsStack:okMsg(string.capitalize(model:getLabel()).." was created successfully!")
								form:setValues{}
							else
								msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not created!")
								form:addErrors(record:getErrors())
							end
						end
					else
						local record = model()
						form:initModel(record)
						if record:save() then
							ActionLog:logCreate(urlConf:getBaseUri(), user, admin, record)
							msgsStack:okMsg(string.capitalize(model:getLabel()).." was created successfully!")
							form:setValues{}
						else
							msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not created!")
							form:addErrors(record:getErrors())
						end
					end
				end
				luv:assign{
					ipairs=ipairs;capitalize=string.capitalize;
					tostring=tostring;html=html;
					user=user;model=model;urlConf=urlConf;
					title=model:getLabel();
					titleIcon=admin:getBigIcon();
					form=form;userMsgs=msgsStack:getMsgs();
				}
				luv:display "admin/create.html"
			end};
			{"^/([^/]+)/records/delete/?$"; function (urlConf, modelName)
				local user = getUser(urlConf)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:getModel()
				if not user:canDelete(model) then ws.Http403() end
				local items = luv:getPost "items"
				if "table" ~= type(items) then
					items = {items}
				end
				local records = model:all():filter{pk__in=items}:getValue()
				model:all():filter{pk__in=items}:delete()
				for _, record in pairs(records) do
					ActionLog:logDelete(urlConf:getBaseUri(), user, admin, record)
				end
				io.write ""
			end};
			{"^/([^/]+)/records/?$"; function (urlConf, modelName)
				local user = getUser(urlConf)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:getModel()
				luv:assign{
					type=type;pairs=pairs;ipairs=ipairs;tostring=tostring;capitalize=string.capitalize;html=html;urlConf=urlConf;user=user;
					modelUri=urlConf:getBaseUri().."/"..modelName;admin=admin;model=model;
				}
				if model:isKindOf(models.Tree) then
					local node = luv:getPost "node"
					if node then
						node = getObjectOr404(model, node)
						luv:assign{parent=node;nodes=node:getChildren()}
					else
						node = model:findRoot()
						if not node then ws.Http404() end
						luv:assign{nodes={node}}
						luv:assign{isRoot=true}
					end
					luv:display "admin/_records-tree.html"
				else
					local page = tonumber(luv:getPost "page") or 1
					luv:assign{
						model=model;page=page;
						displayFields=admin:getDisplayList();
						fields=fields;date=os.date;
						p=models.Paginator(model, 10);
						title=model:getLabelMany();
					}
					luv:display "admin/_records-table.html"
				end
			end};
			{"^/([^/]+)/(.+)/create/?$"; function (urlConf, modelName, recordId) -- for TreeModel
				local user = getUser(urlConf)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:getModel()
				if not user:canCreate(model) then ws.Http403() end
				if not model:isKindOf(models.Tree) then ws.Http404() end
				local record = getObjectOr404(model, recordId)
				local form = admin:getForm():addField("create", fields.Submit(string.capitalize(tr "create")))(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted "create" and form:isValid() then
					local child = model()
					form:initModel(child)
					if record:addChild(child) then
						ActionLog:logCreate(urlConf:getBaseUri(), user, admin, child)
						msgsStack:okMsg(string.capitalize(model:getLabel()).." was created successfully!")
						form:setValues{}
					else
						msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not created!")
						form:addErrors(record:getErrors())
					end
				end
				luv:assign{
					ipairs=ipairs;capitalize=string.capitalize;
					tostring=tostring;html=html;
					user=user;model=model;urlConf=urlConf;
					title=model:getLabel();
					titleIcon=admin:getBigIcon();
					form=form;userMsgs=msgsStack:getMsgs();
				}
				luv:display "admin/create.html"
			end};
			{"^/([^/]+)/(.+)/?$"; function (urlConf, modelName, recordId)
				local user = getUser(urlConf)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:getModel()
				if not user:canEdit(model) then ws.Http403() end
				local record = getObjectOr404(model, recordId)
				local form = admin:getForm()
				if user:canDelete(model) then
					form:addField("delete", fields.Submit{defaultValue=string.capitalize(tr "delete");onClick="return confirm('O\\'RLY?')"})
				end
				form:addField("save", fields.Submit(string.capitalize(tr "save")))
				form = form(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted "save" then
					if form:isValid() then
						form:initModel(record)
						if record:save() then
							ActionLog:logSave(urlConf:getBaseUri(), user, admin, record)
							msgsStack:okMsg(string.capitalize(model:getLabel()).." was saved successfully!")
						else
							msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not saved!")
						end
					end
				elseif form:isSubmitted "delete" then
					if not user:canDelete(model) then ws.Http403() end
					record:delete()
					ActionLog:logDelete(urlConf:getBaseUri(), user, admin, record)
					luv:setResponseHeader("Location", urlConf:getBaseUri().."/"..modelName):sendHeaders()
				else
					form:initForm(record)
				end
				luv:assign{
					ipairs=ipairs;capitalize=string.capitalize;
					tostring=tostring;html=html;
					user=user;record=record;urlConf=urlConf;
					title=model:getLabel();
					titleIcon=admin:getBigIcon();
					form=form;userMsgs=msgsStack:getMsgs();
				}
				luv:display "admin/edit.html"
			end};
			{"^/([^/]+)/?$"; function (urlConf, modelName)
				local user = getUser(urlConf)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:getModel()
				luv:assign{
					capitalize=string.capitalize;
					tostring=tostring;
					user=user;
					model=model;
					urlConf=urlConf;
					title=model:getLabelMany();
					titleIcon=admin:getBigIcon();
					isTree=model:isKindOf(models.Tree);
				}
				luv:display "admin/records.html"
			end};
			{"^/?$"; function (urlConf)
				local user = getUser(urlConf)
				luv:assign{
					actionLogs=ActionLog:all(0, 10):order"-datetime":getValue();
					isEmpty=table.isEmpty;
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

return {ModelAdmin=ModelAdmin;AdminSite=AdminSite;models={ActionLog}}
