require "luv.string"
local io, ipairs, tostring, pairs, table, tonumber, string = io, ipairs, tostring, pairs, table, tonumber, string
local debug, unpack, type, rawget, select = debug, unpack, type, rawget, select
local Object, auth, models, html = require "luv.oop".Object, require "luv.contrib.auth", require "luv.db.models", require "luv.utils.html"
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
	isTree = function (self) return self:getModel():isKindOf(models.Tree) end;
	initModelByForm = function (self, model, form) model:setValues(form:getValues()) return self end;
	initFormByModel = function (self, form, model) form:setValues(model:getValues()) return self end;
}

local ActionLog = models.Model:extend{
	__tag = .....".ActionLog";
	Meta = {labels={"action log";"action logs"}};
	datetime = fields.Datetime{autoNow=true;label="Date and time";required=true};
	user = references.ManyToOne{references=auth.models.User;required=true;relatedName="actionLogs"};
	type = fields.Text{required=true};
	message = fields.Text{maxLength=false;required=true};
	__tostring = function (self) return tostring(self.message) end;
	logAdd = function (self, baseUri, user, admin, record)
		self:create{user=user;type="add";message="Added "..record:getLabel().." "..[[<a href="]]..baseUri.."/"..admin:getPath().."/"..tostring(record.pk)..[[">]]..tostring(record).."</a> by "..tostring(user).."."}
	end;
	logSave = function (self, baseUri, user, admin, record)
		self:create{user=user;type="save";message="Edited "..record:getLabel().." "..[[<a href="]]..baseUri.."/"..admin:getPath().."/"..tostring(record.pk)..[[">]]..tostring(record).."</a> by "..tostring(user).."."}
	end;
	logDelete = function (self, baseUri, user, admin, record)
		self:create{user=user;type="delete";message="Deleted "..record:getLabel().." "..tostring(record).." by "..tostring(user).."."}
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
		luv:debug(luv:getPostData())
		local function getUser (urlConf)
			local user = auth.models.User:getAuthUser(luv:getSession())
			if not user or not user.isActive then luv:setResponseHeader("Location", urlConf:getBaseUri().."/login"):sendHeaders() end
			return user
		end
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
			{"^/([^/]+)/add/?$"; function (urlConf)
				local user = getUser(urlConf)
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then ws.Http404():throw() end
				local model = admin:getModel()
				local form = admin:getForm():addField("add", fields.Submit "Add")(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted("add") and form:isValid() then
					if model:isKindOf(models.Tree) then
						if model:findRoot() then
							msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not added!")
							form:addError "Root record already exist."
						else
							local record = model()
							record.left = 1
							record.right = 2
							admin:initModelByForm(record, form)
							if record:save() then
								ActionLog:logAdd(urlConf:getBaseUri(), user, admin, record)
								msgsStack:okMsg(string.capitalize(model:getLabel()).." was added successfully!")
								form:setValues{}
							else
								msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not added!")
								form:addErrors(record:getErrors())
							end
						end
					else
						local record = model()
						admin:initModelByForm(record, form)
						if record:save() then
							ActionLog:logAdd(urlConf:getBaseUri(), user, admin, record)
							msgsStack:okMsg(string.capitalize(model:getLabel()).." was added successfully!")
							form:setValues{}
						else
							msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not added!")
							form:addErrors(record:getErrors())
						end
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
			{"^/([^/]+)/records/delete/?$"; function (urlConf)
				local user = getUser(urlConf)
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then ws.Http404():throw() end
				local model = admin:getModel()
				local items = luv:getPost "items"
				if "table" ~= type(items) then
					items = {items}
				end
				local records = model:all():filter{pk__in=items}:getValue()
				model:all():filter{pk__in=items}:delete()
				local _, record
				for _, record in pairs(records) do
					ActionLog:logDelete(urlConf:getBaseUri(), user, admin, record)
				end
				io.write ""
			end};
			{"^/([^/]+)/records/?$"; function (urlConf)
				local user = getUser(urlConf)
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then ws.Http404():throw() end
				local model = admin:getModel()
				luv:assign{
					pairs=pairs;ipairs=ipairs;tostring=tostring;capitalize=string.capitalize;html=html;urlConf=urlConf;user=user;
					modelUri=urlConf:getBaseUri().."/"..urlConf:getCapture(1);model=model;
				}
				if model:isKindOf(models.Tree) then
					local node = luv:getPost "node"
					if node then
						node = model:find(node)
						if not node then ws.Http404():throw() end
						luv:assign{parent=node;nodes=node:getChildren()}
					else
						node = model:findRoot()
						if not node then ws.Http404():throw() end
						luv:assign{nodes={node}}
						luv:assign{isRoot=true}
					end
					luv:display "admin/_records-tree.html"
				else
					local page = tonumber(luv:getPost "page") or 1
					luv:assign{
						model=model;page=page;
						fields=admin:getDisplayList();
						p=models.Paginator(model, 10);
						title=string.capitalize(model:getLabelMany());
					}
					luv:display "admin/_records-table.html"
				end
			end};
			{"^/([^/]+)/(.+)/add/?$"; function (urlConf) -- for TreeModel
				local user = getUser(urlConf)
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then ws.Http404():throw() end
				local model = admin:getModel()
				if not model:isKindOf(models.Tree) then ws.Http404:throw() end
				local record = model:find(urlConf:getCapture(2))
				if not record then ws.Http404():throw() end
				local form = admin:getForm():addField("add", fields.Submit "Add")(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted "add" and form:isValid() then
					local child = model()
					admin:initModelByForm(child, form)
					if record:addChild(child) then
						ActionLog:logAdd(urlConf:getBaseUri(), user, admin, child)
						msgsStack:okMsg(string.capitalize(model:getLabel()).." was added successfully!")
						form:setValues{}
					else
						msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not added!")
						form:addErrors(record:getErrors())
					end
				end
				luv:assign{
					ipairs=ipairs;capitalize=string.capitalize;
					tostring=tostring;html=html;
					user=user;model=model;urlConf=urlConf;
					title="Add "..model:getLabel();
					form=form;userMsgs=msgsStack:getMsgs();
				}
				luv:display "admin/add.html"
			end};
			{"^/([^/]+)/(.+)/?$"; function (urlConf)
				local user = getUser(urlConf)
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then ws.Http404():throw() end
				local model = admin:getModel()
				local record = model:find(urlConf:getCapture(2))
				if not record then ws.Http404():throw() end
				local form = admin:getForm()
				form:addField("delete", fields.Submit{defaultValue="Delete";onClick="return confirm('O\\'RLY?')"})
				form:addField("save", fields.Submit "Save")
				form = form(luv:getPostData()):setAction(urlConf:getUri())
				local msgsStack = UserMsgsStack()
				if form:isSubmitted "save" then
					if form:isValid() then
						admin:initModelByForm(record, form)
						if record:save() then
							ActionLog:logSave(urlConf:getBaseUri(), user, admin, record)
							msgsStack:okMsg(string.capitalize(model:getLabel()).." was saved successfully!")
						else
							msgsStack:errorMsg(string.capitalize(model:getLabel()).." was not saved!")
						end
					end
				elseif form:isSubmitted "delete" then
					record:delete()
					ActionLog:logDelete(urlConf:getBaseUri(), user, admin, record)
					luv:setResponseHeader("Location", urlConf:getBaseUri().."/"..urlConf:getCapture(1)):sendHeaders()
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
			{"^/([^/]+)/?$"; function (urlConf)
				local user = getUser(urlConf)
				local admin = self:findAdmin(urlConf:getCapture(1))
				if not admin then ws.Http404():throw() end
				local model = admin:getModel()
				luv:assign{
					capitalize=string.capitalize;
					tostring=tostring;
					user=user;
					model=model;
					urlConf=urlConf;
					title=string.capitalize(model:getLabelMany());
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
