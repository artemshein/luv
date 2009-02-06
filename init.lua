require"luv.table"
require"luv.string"
require"luv.debug"
local pairs, require, select, unpack, string, table, debug, type, rawget, rawset, math, os, tostring, io, ipairs = pairs, require, select, unpack, string, table, debug, type, rawget, rawset, math, os, tostring, io, ipairs
local _G = _G
local oop, exceptions, utils, sessions, fs = require"luv.oop", require"luv.exceptions", require"luv.utils", require "luv.sessions", require "luv.fs"
local Object, Exception, Version = oop.Object, exceptions.Exception, utils.Version

module(...)

local function dropModel (db, modelName, models)
	local model = (type(modelName) == "string" and require(modelName)) or modelName
	model:setDb(db)
	-- Drop constraints
	local constraintModels, _, v = model:getConstraintModels()
	for _, v in pairs(constraintModels) do
		if models[v] then
			models[v] = false
			dropModel(db, v, models)
		end
	end
	-- Drop self
	if not model:dropTables() then
		return false
	else
		return true
	end
end

local function createModel (db, modelName, models)
	local model = (type(modelName) == "string" and require(modelName)) or modelName
	model:setDb(db)
	-- Create self
	if not model:createTables() then
		return false
	else
		return true
	end
	-- Create constraints
	local constraintModels, _, v = model:getConstraintModels()
	for _, v in pairs(constraintModels) do
		if models[v] then
			models[v] = false
			createModel(db, v, models)
		end
	end
end

local UrlConf = Object:extend{
	__tag = .....".UrlConf",
	init = function (self, wsApi)
		self.uri = wsApi:getRequestHeader("REQUEST_URI") or ""
		local queryPos = string.find(self.uri, "?")
		if queryPos then
			self.uri = string.sub(self.uri, 1, queryPos-1)
		end
	end,
	capture = function (self, pos)
		return self.captures[pos]
	end,
	execute = function (self, action)
		if type(action) == "string" then
			dofile(action)
		elseif type(action) == "function" then
			action(self)
		else
			Exception "Invalid action!":throw()
		end
	end,
	dispatch = function (self, urls)
		for expr, script in pairs(urls) do
			if "string" == type(expr) then
				local res = {string.find(self.uri, expr)}
				if nil ~= res[1] then
					self.uri = string.sub(self.uri, res[2]+1)
					self.captures = {}
					local i = 3
					for i = 3, #res do
						table.insert(self.captures, res[i])
					end
					self:execute(script)
					return true
				end
			end
		end
		local action = urls[false]
		if action then self:execute(action) return true end
		return false
	end
}

local Core = Object:extend{
	__tag = .....".Core",
	version = Version(0, 3, 0, "dev"),
	-- Init
	init = function (self, wsApi, dsn)
		-- Init random seed
		local seed, i, str = os.time(), nil, tostring(tostring(self))
		for i = 1, string.len(str) do
			seed = seed + string.byte(str, i)
		end
		math.randomseed(seed)
		--
		self.wsApi = wsApi:setResponseHeader("X-Powered-By", "Luv/"..tostring(self.version))
		--self.wsApi:setResponseHeader("Content-type", "text/html;charset=utf8")
		self.urlconf = UrlConf(wsApi)
		self.templater = require "luv.templaters.tamplier" ("templates/")
		self.session = sessions.Session(self.wsApi, sessions.SessionFile("/var/www/sessions/"))
		local db, models = require "luv.db", require "luv.db.models"
		self.db = models.Model:setDb(db.Factory(dsn))
	end,
	getDsn = function (self) return self.dsn end,
	setDsn = function (self, dsn)
		self.dsn = dsn
		self.db = require "luv.db".Factory(dsn)
		return self
	end,
	getDb = function (self) return self.db end,
	-- Web-server
	getRequestHeader = function (self, ...) return self.wsApi:getRequestHeader(...) end,
	setResponseHeader = function (self, ...) self.wsApi:setResponseHeader(...) return self end,
	getGet = function (self, name) return self.wsApi:getGet(name) end,
	getGetData = function (self) return self.wsApi:getGetData() end,
	getPost = function (self, name) return self.wsApi:getPost(name) end,
	getPostData = function (self) return self.wsApi:getPostData() end,
	getCookie = function (self, name) return self.wsApi:getCookie(name) end,
	setCookie = function (self, ...) self.wsApi:setCookie(...) return self end,
	getCookies = function (self) return self.wsApi:getCookies() end,
	getSession = function (self) return self.session end,
	setSession = function (self, session) self.session = session return self end,
	-- URL conf
	dispatch = function (self, urlconf) return self.urlconf:dispatch(urlconf) end,
	-- Models
	iterateModels = function (self, modelsList, iterator)
		local modelsList = modelsList or {}
		local models, result, _, k, v = {}, true
		for _, v in pairs(modelsList) do
			models[v] = true
		end
		for k, _ in pairs(models) do
			models[k] = false
			iterator(self.db, k, models)
		end
		--return result
	end,
	dropModels = function (self, ...)
		local i	for i = 1, select("#", ...) do
			self:iterateModels(select(i, ...), dropModel)
		end
	end,
	createModels = function (self, ...)
		local i	for i = 1, select("#", ...) do
			self:iterateModels(select(i, ...), createModel)
		end
	end,
	-- Templater
	addTemplatesDir = function (self, templatesDir)
		self.templater:addTemplatesDir(templatesDir)
		return self
	end,
	assign = function (self, ...)
		self.templater:assign(...)
		return self
	end,
	fetch = function (self, template)
		return self.templater:fetch(template)
	end,
	display = function (self, template)
		return self.templater:display(template)
	end
}

local Struct = Object:extend{
	__tag = .....".Struct",
	init = function (self)
		self.errors = {}
	end,
	__index = function (self, field)
		if field == "pk" then return self:getPk():getValue() end
		local res = rawget(self, "fields")
		if res then
			res = res[field]
			if res then
				return res:getValue()
			end
		end
		return rawget(self, "parent")[field]
	end,
	__newindex = function (self, field, value)
		local res = self:getField(field)
		if res then
			res:setValue(value)
		else
			rawset(self, field, value)
		end
		return value
	end,
	isValid = function (self)
		local k, v
		self:setErrors{}
		for k, v in pairs(self.fields) do
			if not v:isValid() then
				local _, e for _, e in ipairs(v:getErrors()) do
					local label = v:getLabel()
					self:addError(string.gsub(e, "%%s", label and string.capitalize(label) or k))
				end
				return false
			end
		end
		return true
	end,
	addError = function (self, error) table.insert(self.errors, error) return self end,
	setErrors = function (self, errors) self.errors = errors return self end,
	addErrors = function (self, errors)
		local i, v for i, v in ipairs(errors) do
			table.insert(self.errors, v)
		end
	end,
	getErrors = function (self) return self.errors end,
	getErrorsCount = function (self) return table.maxn(self.errors) end,
	getField = function (self, field)
		if not self.fields then
			Exception"Fields must be defined first!":throw()
		end
		return self.fields[field]
	end,
	getFields = function (self)
		return self.fields
	end,
	getValues = function (self)
		local res = {}
		local k, v
		for k, v in pairs(self.fields) do
			res[k] = v:getValue()
		end
		return res
	end,
	setValues = function (self, values)
		local k, v
		for k, v in pairs(self.fields) do
			v:setValue(values[k])
		end
	end
}

local Widget = Object:extend{
	__tag = .....".Widget",
	render = Object.abstractMethod
}

return {
	oop = oop,
	exceptions = exceptions,
	util = util,
	Core = Core,
	UrlConf = UrlConf,
	Struct = Struct,
	Widget = Widget
}
	
