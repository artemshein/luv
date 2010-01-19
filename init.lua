local table = require"luv.table"
local string = require"luv.string"
local dev = require"luv.dev"
local pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile = pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile
local error, debug = error, debug
local oop, exceptions, sessions, fs, ws, sessions, utils = require"luv.oop", require"luv.exceptions", require "luv.sessions", require "luv.fs", require "luv.webservers", require "luv.sessions", require "luv.utils"
local Object, Exception, Version = oop.Object, exceptions.Exception, utils.Version
local crypt, backend = require "luv.crypt", require "luv.cache.backend"
local Memory, NamespaceWrapper, TagEmuWrapper = backend.Memory, backend.NamespaceWrapper, backend.TagEmuWrapper
local Slot = require "luv.cache.frontend".Slot
local checkTypes = require"luv.checktypes".checkTypes

module(...)

local MODULE = (...)
local property = Object.property
local abstract = Object.abstractMethod
local singleton = Object.singleton

string.tr = string.tr or function (str) return str end

(function () -- Init random seed
	local seed, i, str = os.time(), nil, tostring(tostring(MODULE))
	for i = 1, #str do
		seed = seed + str:byte(i)
	end
	math.randomseed(seed)
end)() -- Excecute it imediately


local TemplateSlot = Slot:extend{
	__tag = .....".TemplateSlot";
	luv = property;
	template = property;
	init = function (self, luv, template, params)
		self:luv(luv)
		self:template(template)
		return Slot.init(self, luv:cacher(), tostring(crypt.Md5(template..string.serialize(params))), 60*60)
	end;
	displayCached = function (self)
		local res = self:get()
		if not res then return false end
		io.write(res)
		return true
	end;
	display = function (self)
		self:luv():info("Template cache date "..os.date(), "Cacher")
		local res = self:luv():fetch(self:template())
		self:set(res)
		io.write(res)
		return self
	end;
}

local Struct = Object:extend{
	__tag = .....".Struct";
	errors = property"table";
	msgs = property"table";
	fields = property("table", nil, function (self, fields)
		self._fields = {}
		for name, f in pairs(fields) do
			self:addField(name, f)
		end
		return self
	end);
	init = function (self)
		self:msgs{}
		self:errors{}
	end;
	pkField = function (self)
		for _, f in pairs(self:fields()) do
			if f:pk() then return f end
		end
		return nil
	end;
	__index = function (self, field)
		if field == "pk" then return self:pkField():value() end
		local res = rawget(self, "_fields")
		if res then
			res = res[field]
			if res then
				local references = require"luv.fields.references"
				if res:isA(references.ManyToMany) or res:isA(references.OneToMany)then
					return res
				else
					return res:value()
				end
			end
		end
		return rawget(self, "_parent")[field]
	end;
	__newindex = function (self, field, value)
		if "pk" == field then self:pkField():value(value) return self end
		local res = self:field(field)
		if res then
			res:value(value)
		else
			rawset(self, field, value)
		end
		return value
	end;
	-- Fields
	addField = function (self, name, field)
		local fields = self:fields() or Exception"fields required"
		if not field:isA(require"luv.fields".Field) then
			Exception"instance of Field expected"
		end
		field:container(self)
		field:name(name)
		fields[name] = field
		return self
	end;
	removeField = function (self, name)
		local fields = self:fields() or Exception"fields required"
		fields[name] = nil
	end;
	field = function (self, field) return self:fields()[field] end;
	values = function (self, ...)
		if select("#", ...) > 0 then
			local values = (select(1, ...))
			for name, f in pairs(self:fields()) do
				f:value(values[name])
			end
			return self
		else
			local res = {}
			for name, f in pairs(self:fields()) do
				local value = f:value()
				if "table" == type(value) and value.isA and value:isA(require"luv.fields.references".OneToMany) then
					res[name] = value:all():value()
				else
					res[name] = f:value()
				end
			end
			return res
		end
	end;
	-- Validation & errors collect
	valid = function (self)
		self:errors{}
		for name, f in pairs(self:fields()) do
			if not f:valid() then
				for _, e in ipairs(f:errors()) do
					local label = f:label()
					self:addError(e:gsub("%%s", label and label:tr():capitalize() or name:tr():capitalize()))
				end
			end
		end
		return table.empty(self:errors())
	end;
	addError = checkTypes(nil, "string", function (self, error) table.insert(self._errors, error) return self end);
	addErrors = checkTypes(nil, "table", function (self, errors)
		for _, error in ipairs(errors) do
			self:addError(error)
		end
	end);
	addMsg = checkTypes(nil, "string", function (self, msg) table.insert(self._msgs, msg) return self end);
	addMsgs = checkTypes(nil, "table", function (self, msgs)
		for _, msg in ipairs(msgs) do
			self:addMsg(msg)
		end
		return self
	end);
}

local Widget = Object:extend{
	__tag = .....".Widget";
	render = abstract;
}

local objectOr404 = function (model, conditions)
	local obj = model:find(conditions)
	if not obj then
		ws.Http404()
	end
	return obj
end

local Luv = Object:extend{
	__tag = .....".Luv";
	env = property"table";
	response = property;
	new = singleton;
	clone = singleton;
	init = function (self, env)
		env = env or {}
		local ws = require"luv.webservers"
		wsApi = env.wsApi or ws.Cgi(env.tmpDir)
		if env.sessionsDir then
			wsApi:startSession(require"luv.sessions".SessionFile(env.sessionsDir))
		end
		self:response(ws.HttpResponse(wsApi))
		env.i18n = require"luv.i18n".I18n("app/i18n", wsApi:cookie"language" or wsApi)
		if env.templatesDirs then
			env.templater = require"luv.templaters".Tamplier(env.templatesDirs, env.urlPrefix, env.mediaPrefix)
		end
		if env.dsn then
			env.db = require"luv.db".Factory(env.dsn)
			require"luv.db.models".Model:db(env.db)
		end
		if env.urlPrefix then
			require"luv.db.models".Model:urlPrefix(env.urlPrefix)
			require"luv.forms".Form:urlPrefix(env.urlPrefix)
		end
		env.urlConf = ws.UrlConf(ws.HttpRequest(wsApi), env.urlPrefix, env.mediaPrefix)
		if env.debugMode then
			env.debugger = env.debugMode and require"luv.dev.debuggers".Fire()
			if env.db then
				env.db:logger(function (sql, result) env.debugger:debug(sql..", returns "..("table" == type(result) and "table" or tostring(result)), "Database") end)
			end
		end
		if env.secretSalt then
			require"luv.contrib.auth".models.User:secretSalt(env.secretSalt)
		end
		local jsScripts = {"jquery-1.3.2.min.js";"jquery.form.js";"data.js";"forms.js";"validators.js";"browsers.js";"jquery-ui-1.7.2.custom.min.js"}
		env.templater:assign{
			mediaPrefix=env.mediaPrefix;urlPrefix=env.urlPrefix;debugger=env.debugger or "";
			jsScripts = jsScripts;
			i18n = env.i18n;
			urlConf = env.urlConf;
			luvVersion = require"luv.utils".Version"1a";
			importJsScripts = function ()
				local res, prefix = "", env.mediaPrefix
				if not prefix and env.urlPrefix then
					prefix = env.urlPrefix
				end
				for _, script in ipairs(jsScripts) do
					res = res..'<script type="text/javascript" language="JavaScript" src="'..(prefix or "").."/js/luv/"..script..'"></script>'
				end
				return res
			end;
		}
		if env.assign then
			env.templater:assign(env.assign)
		end
		self:env(env)
		return self
	end;
	dispatch = function (self, urls)
		if not self:env().urlConf:environment(self:env()):dispatch(urls) then
			require"luv.webservers".Http404()
		end
		return self
	end;
}

return {
	Struct=Struct;Widget=Widget;objectOr404=objectOr404;Luv=Luv;
}
	
