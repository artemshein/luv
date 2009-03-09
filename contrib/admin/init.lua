local io, ipairs, tostring, pairs, table = io, ipairs, tostring, pairs, table
local string = require "luv.string"
local Object, auth = require "luv.oop".Object, require "luv.contrib.auth"

module(...)

return function (luv, categories)
	local _, model, modelsCategories, modelsList
	modelsCategories = {}
	for _, modelsList in ipairs(categories) do
		for _, model in pairs(modelsList) do
			local category = model:getCategory() or "not categorised"
			modelsCategories[category] = modelsCategories[category] or {}
			table.insert(modelsCategories[category], model)
		end
	end
	return function (urlConf)
		local baseUri = urlConf:getBaseUri()
		luv:dispatch{
			["/login"] = function (urlConf)
				local form = auth.forms.LoginForm(luv:getPostData())
				local user = auth.models.User:getAuthUser(luv:getSession(), form)
				if user then luv:setResponseHeader("Location", baseUri):sendHeaders() end
				luv:assign{ipairs=ipairs;tostring=tostring;form=form;user=user}
				luv:display "admin/login.html"
			end;
			["/logout"] = function ()
				auth.models.User:logout(luv:getSession())
				luv:setResponseHeader("Location", "/"):sendHeaders()
			end;
			[false] = function (urlConf)
				local user = auth.models.User:getAuthUser(luv:getSession())
				if not user then luv:setResponseHeader("Location", baseUri.."/login"):sendHeaders() end
				luv:assign{
					pairs=pairs;ipairs=ipairs;
					tostring=tostring;
					baseUri=baseUri;
					user=user;
					capitalize=string.capitalize;lower=string.lower;
					title="AdminSite";
					categories=modelsCategories;
				}
				luv:display "admin/main.html"
			end;
		}
	end;
end
