require "luv.string"
local io, ipairs, tostring, pairs, table, tonumber, string = io, ipairs, tostring, pairs, table, tonumber, string
local debug = debug
local Object, auth, models, html = require "luv.oop".Object, require "luv.contrib.auth", require "luv.db.models", require "luv.utils.html"
local fields = require "luv.fields"
local forms = require "luv.forms"

module(...)

local function getFormFor (model)
	local adminForm = model:getAdminForm()
	if adminForm then
		return adminForm
	end
	return forms.ModelForm:extend{Meta={model=model}}
end;

return function (luv, modelsList)
	local modelsCategories, _, model = {}
	for _, model in ipairs(modelsList) do
		local category = model:getCategory() or "not categorised"
		modelsCategories[category] = modelsCategories[category] or {}
		table.insert(modelsCategories[category], model)
	end
	function findModel (path)
		local category, models, model
		for category, models in pairs(modelsCategories) do
			for _, model in ipairs(models) do
				if model:getPath() == path then return model end
			end
		end
		return false
	end
	return function (urlConf)
		local baseUri = urlConf:getBaseUri()
		luv:dispatch{
			{"^/login$"; function (urlConf)
				local form = auth.forms.LoginForm(luv:getPostData())
				local user = auth.models.User:getAuthUser(luv:getSession(), form)
				if user and user.isActive then luv:setResponseHeader("Location", baseUri):sendHeaders() end
				luv:assign{
					capitalize=string.capitalize;
					title="Authorisation";
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
				if not user or not user.isActive then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
				local model = findModel(urlConf:getCapture(1))
				if not model then return false end
				luv:assign{
					ipairs=ipairs;
					capitalize=string.capitalize;
					tostring=tostring;
					html=html;
					baseUri=baseUri;
					user=user;
					model=model;
					urlConf=urlConf;
					title="Add "..model:getLabel();
					form=getFormFor(model):addField("add", fields.Submit "Add")();
				}
				luv:display "admin/add.html"
			end};
			{"^/([^/]+)/records$"; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
				local model = findModel(urlConf:getCapture(1))
				if not model then return false end
				if model:isKindOf(models.TreeModel) then
					luv:assign{
						ipairs=ipairs;tostring=tostring;
						nodes={model:findRoot()};
						isRoot=true;
					}
					luv:display "admin/_records-tree.html"
				else
					local page = tonumber(luv:getPost "page") or 1
					luv:assign{
						ipairs=ipairs;
						capitalize=string.capitalize;
						tostring=tostring;
						html=html;
						baseUri=baseUri;
						user=user;
						model=model;
						page=page;
						fields=model:getDisplayList();
						p=models.Paginator(model, 10);
						urlConf=urlConf;
						title=string.capitalize(model:getLabelMany());
					}
					luv:display "admin/_records-table.html"
				end
			end};
			{"^/([^/]+)$"; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
				local model = findModel(urlConf:getCapture(1))
				if not model then return false end
				luv:assign{
					capitalize=string.capitalize;
					tostring=tostring;
					baseUri=baseUri;
					user=user;
					model=model;
					urlConf=urlConf;
					title=string.capitalize(model:getLabelMany());
				}
				luv:display "admin/records.html"
			end};
			{false; function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user or not user.isActive then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
				luv:assign{
					pairs=pairs;ipairs=ipairs;
					tostring=tostring;
					baseUri=baseUri;
					user=user;
					capitalize=string.capitalize;lower=string.lower;replace=string.replace;
					title="AdminSite";
					categories=modelsCategories;
				}
				luv:display "admin/main.html"
			end};
		}
	end;
end
