require "luv.string"
local io, ipairs, tostring, pairs, table, tonumber, string = io, ipairs, tostring, pairs, table, tonumber, string
local debug = debug
local Object, auth, models, html = require "luv.oop".Object, require "luv.contrib.auth", require "luv.db.models", require "luv.utils.html"

module(...)

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
	end
	return function (urlConf)
		local baseUri = urlConf:getBaseUri()
		luv:dispatch{
			["^/login"] = function (urlConf)
				local form = auth.forms.LoginForm(luv:getPostData())
				local user = auth.models.User:getAuthUser(luv:getSession(), form)
				if user then luv:setResponseHeader("Location", baseUri):sendHeaders() end
				luv:assign{ipairs=ipairs;tostring=tostring;form=form;user=user}
				luv:display "admin/login.html"
			end;
			["^/logout"] = function ()
				auth.models.User:logout(luv:getSession())
				luv:setResponseHeader("Location", "/"):sendHeaders()
			end;
			["^/([^/]+)/records$"] = function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
				local model = findModel(urlConf:getCapture(1))
				if not model then return false end
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
			end;
			["^/([^/]+)$"] = function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
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
			end;
			[false] = function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
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
			end;
		}
	end;
end
