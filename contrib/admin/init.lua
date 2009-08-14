local string = require"luv.string"
local io, ipairs, tostring, pairs, table, tonumber = io, ipairs, tostring, pairs, table, tonumber
local unpack, type, rawget, select = unpack, type, rawget, select
local os, require = os, require
local Object, auth, models, html = require"luv.oop".Object, require"luv.contrib.auth", require"luv.db.models", require"luv.utils.html"
local objectOr404 = require"luv".objectOr404
local fields = require"luv.fields"
local forms = require"luv.forms"
local json = require"luv.utils.json"
local references = require"luv.fields.references"
local ws = require"luv.webservers"

module(...)

local property = Object.property

local ModelAdmin = Object:extend{
	__tag = .....".ModelAdmin";
	model = property(models.Model);
	smallIcon = property;
	bigIcon = property;
	category = property"string";
	path = property("string", function (self)
		if not self._path then
			self:path(self:model():labelMany():lower():replace(" ", "_"))
		end
		return self._path
	end);
	fields = property"table";
	displayList = property("table", function (self)
		if not self._displayList then
			local res, field = {}
			for name, _ in pairs(self:model():fields()) do
				table.insert(res, name)
			end
			self:displayList(res)
		end
		return self._displayList
	end);
	form = property(nil, function (self)
		if not self._form then
			self:form(forms.ModelForm:extend{Meta={id="form";model=self:model();fields=self:fields()}})
		end
		return self._form
	end);
	tree = function (self) return self:model():isA(models.Tree) end;
}

local ActionLog = models.Model:extend{
	__tag = .....".ActionLog";
	__tostring = function (self) return tostring(self.message) end;
	Meta = {labels={("action log"):tr();("action logs"):tr()}};
	datetime = fields.Datetime{autoNow=true;label=("date and time"):tr();required=true};
	user = references.ManyToOne{references=auth.models.User;required=true;relatedName="actionLogs"};
	type = fields.Text{required=true};
	message = fields.Text{maxLength=false;required=true};
	logCreate = function (self, baseUri, user, admin, record)
		self:create{user=user;type=("creating"):tr();message="Created "..record:label().." "..[[<a href="]]..baseUri.."/"..admin:path().."/"..tostring(record.pk)..[[">]]..tostring(record).."</a> by "..tostring(user).."."}
	end;
	logSave = function (self, baseUri, user, admin, record)
		self:create{user=user;type=("changing"):tr();message="Edited "..record:label().." "..[[<a href="]]..baseUri.."/"..admin:path().."/"..tostring(record.pk)..[[">]]..tostring(record).."</a> by "..tostring(user).."."}
	end;
	logDelete = function (self, baseUri, user, admin, record)
		self:create{user=user;type=("deleting"):tr();message="Deleted "..record:label().." "..tostring(record).." by "..tostring(user).."."}
	end;
}

local UserMsgsStack = Object:extend{
	__tag = .....".UserMsgsStack";
	msgs = property"table";
	init = function (self) self:msgs{} end;
	okMsg = function (self, msg)
		table.insert(self:msgs(), {msg=msg;status="ok"})
		return self
	end;
	errorMsg = function (self, msg)
		table.insert(self:msgs(), {msg=msg;status="error"})
		return self
	end;
}

local AdminSite = Object:extend{
	__tag = .....".AdminSite";
	luv = property;
	modelsCategories = property"table";
	init = function (self, luv, ...)
		self:luv(luv)
		local modelsList = {...}
		local modelsCategories = {}
		for i = 1, select("#", ...) do
			for _, model in ipairs(modelsList[i]) do
				local category, admin
				if "table" == type(model) and model.isA and model:isA(models.Model) then
					admin = ModelAdmin:extend{model=model}
				else
					admin = model
				end
				category = admin:category() or ("not categorised"):tr()
				modelsCategories[category] = modelsCategories[category] or {}
				table.insert(modelsCategories[category], admin)
			end
		end
		self:modelsCategories(modelsCategories)
	end;
	findAdmin = function (self, path)
		for category, admins in pairs(self:modelsCategories()) do
			for _, admin in ipairs(admins) do
				if admin:path() == path then return admin end
			end
		end
		return false
	end;
	urls = function (self)
		local luv = self:luv()
		luv:debug(luv:postData())
		local function authUser (urlConf)
			local user = auth.models.User:authUser(luv:session())
			if not user or not user.isActive then luv:responseHeader("Location", urlConf:baseUri().."/login"):sendHeaders() end
			return user
		end
		local function requireAuth (func)
			return function (urlConf, ...)
				return func(urlConf, authUser(urlConf), ...)
			end
		end
		return {
			{"^/login$"; function (urlConf)
				local form = auth.forms.Login(luv:postData())
				local user = auth.models.User:authUser(luv:session(), form)
				if user and user.isActive then luv:responseHeader("Location", urlConf:baseUri()):sendHeaders() end
				luv:assign{
					title=("authorisation"):tr();ipairs=ipairs;
					tostring=tostring;form=form;user=user;
				}
				luv:display"admin/login.html"
			end};
			{"^/logout$"; function (urlConf)
				auth.models.User:logout(luv:session())
				luv:responseHeader("Location", "/"):sendHeaders()
			end};
			{"^/([^/]+)/create/?$"; requireAuth(function (urlConf, user, modelName)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:model()
				if not user:canCreate(model) then ws.Http403() end
				local form = admin:form():addField("create", fields.Submit(("create"):tr():capitalize()))(luv:postData()):action(urlConf:uri())
				local msgsStack = UserMsgsStack()
				if form:submitted"create" and form:valid() then
					if model:isA(models.Tree) then
						if model:findRoot() then
							msgsStack:errorMsg(model:label():capitalize().." was not created!")
							form:addError"Root record already exist."
						else
							local record = model()
							record.left = 1
							record.right = 2
							form:initModel(record)
							if record:save() then
								ActionLog:logCreate(urlConf:baseUri(), user, admin, record)
								msgsStack:okMsg(model:label():capitalize().." was created successfully!")
								form:values{}
							else
								msgsStack:errorMsg(model:label():capitalize().." was not created!")
								form:addErrors(record:errors())
							end
						end
					else
						local record = model()
						form:initModel(record)
						if record:save() then
							ActionLog:logCreate(urlConf:baseUri(), user, admin, record)
							msgsStack:okMsg(model:label():capitalize().." was created successfully!")
							form:values{}
						else
							msgsStack:errorMsg(model:label():capitalize().." was not created!")
							form:addErrors(record:errors())
						end
					end
				end
				luv:assign{
					ipairs=ipairs;tostring=tostring;html=html;
					user=user;model=model;urlConf=urlConf;
					title=model:label();
					titleIcon=admin:bigIcon();
					form=form;userMsgs=msgsStack:msgs();
				}
				luv:display"admin/create.html"
			end)};
			{"^/([^/]+)/records/delete/?$"; requireAuth(function (urlConf, user, modelName)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:model()
				if not user:canDelete(model) then ws.Http403() end
				local items = luv:getPost"items"
				if "table" ~= type(items) then
					items = {items}
				end
				local records = model:all():filter{pk__in=items}:value()
				model:all():filter{pk__in=items}:delete()
				for _, record in pairs(records) do
					ActionLog:logDelete(urlConf:baseUri(), user, admin, record)
				end
				io.write""
			end)};
			{"^/([^/]+)/records/?$"; requireAuth(function (urlConf, user, modelName)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:model()
				luv:assign{
					type=type;pairs=pairs;ipairs=ipairs;tostring=tostring;html=html;urlConf=urlConf;user=user;
					modelUri=urlConf:baseUri().."/"..modelName;admin=admin;model=model;
				}
				if model:isA(models.Tree) then
					local node = luv:post"node"
					if node then
						node = objectOr404(model, node)
						luv:assign{parent=node;nodes=node:children()}
					else
						node = model:findRoot()
						if not node then ws.Http404() end
						luv:assign{nodes={node}}
						luv:assign{isRoot=true}
					end
					luv:display"admin/_records-tree.html"
				else
					local page = tonumber(luv:post"page") or 1
					luv:assign{
						model=model;page=page;
						displayFields=admin:displayList();
						fields=fields;date=os.date;
						p=models.Paginator(model:parent(), 10);
						title=model:labelMany():tr():capitalize();
					}
					luv:display"admin/_records-table.html"
				end
			end)};
			{"^/([^/]+)/(.+)/create/?$"; requireAuth(function (urlConf, user, modelName, recordId) -- for TreeModel
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:model()
				if not user:canCreate(model) then ws.Http403() end
				if not model:isA(models.Tree) then ws.Http404() end
				local record = objectOr404(model, recordId)
				local form = admin:form():addField("create", fields.Submit(("create"):tr():capitalize()))(luv:postData()):action(urlConf:uri())
				local msgsStack = UserMsgsStack()
				if form:submitted "create" and form:valid() then
					local child = model()
					form:initModel(child)
					if record:addChild(child) then
						ActionLog:logCreate(urlConf:baseUri(), user, admin, child)
						msgsStack:okMsg(model:label():capitalize().." was created successfully!")
						form:values{}
					else
						msgsStack:errorMsg(model:label():capitalize().." was not created!")
						form:addErrors(record:errors())
					end
				end
				luv:assign{
					ipairs=ipairs;tostring=tostring;html=html;user=user;
					model=model;urlConf=urlConf;title=model:label();
					titleIcon=admin:bigIcon();
					form=form;userMsgs=msgsStack:msgs();
				}
				luv:display"admin/create.html"
			end)};
			{"^/([^/]+)/(.+)/?$"; requireAuth(function (urlConf, user, modelName, recordId)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:model()
				if not user:canEdit(model) then ws.Http403() end
				local record = objectOr404(model, recordId)
				local form = admin:form()
				if user:canDelete(model) then
					form:addField("delete", fields.Submit{defaultValue=("delete"):tr():capitalize();onClick="return confirm('O\\'RLY?')"})
				end
				form:addField("save", fields.Submit(("save"):tr():capitalize()))
				form = form(luv:postData()):action(urlConf:uri())
				local msgsStack = UserMsgsStack()
				if form:submitted"save" then
					if form:valid() then
						form:initModel(record)
						if record:save() then
							ActionLog:logSave(urlConf:baseUri(), user, admin, record)
							msgsStack:okMsg(model:label():capitalize().." was saved successfully!")
						else
							msgsStack:errorMsg(model:label():capitalize().." was not saved!")
						end
					end
				elseif form:submitted"delete" then
					if not user:canDelete(model) then ws.Http403() end
					record:delete()
					ActionLog:logDelete(urlConf:baseUri(), user, admin, record)
					luv:responseHeader("Location", urlConf:baseUri().."/"..modelName):sendHeaders()
				else
					form:initForm(record)
				end
				luv:assign{
					ipairs=ipairs;tostring=tostring;html=html;
					user=user;record=record;urlConf=urlConf;
					title=model:label();titleIcon=admin:bigIcon();
					form=form;userMsgs=msgsStack:msgs();
				}
				luv:display"admin/edit.html"
			end)};
			{"^/([^/]+)/?$"; requireAuth(function (urlConf, user, modelName)
				local admin = self:findAdmin(modelName)
				if not admin then ws.Http404() end
				local model = admin:model()
				luv:assign{
					tostring=tostring;user=user;model=model;
					urlConf=urlConf;title=model:labelMany():tr():capitalize();
					titleIcon=admin:bigIcon();
					isTree=model:isA(models.Tree);
				}
				luv:display"admin/records.html"
			end)};
			{"^/?$"; requireAuth(function (urlConf, user)
				luv:assign{
					actionLogs=ActionLog:all(0, 10):order"-datetime":value();
					empty=table.empty;pairs=pairs;ipairs=ipairs;
					tostring=tostring;urlConf=urlConf;user=user;
					title=("AdminSite"):tr();
					categories=self:modelsCategories();
				}
				luv:display"admin/main.html"
			end)};
		}
	end;
}

return {ModelAdmin=ModelAdmin;AdminSite=AdminSite;models={ActionLog}}
