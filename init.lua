require"luv.table"
require"luv.string"
require"luv.debug"
local pairs, require, select, unpack, string, table, debug, type, rawget, rawset, math, os, tostring, io, ipairs, dofile = pairs, require, select, unpack, string, table, debug, type, rawget, rawset, math, os, tostring, io, ipairs, dofile
local _G, error = _G, error
local oop, exceptions, utils, sessions, fs, ws, sessions = require"luv.oop", require"luv.exceptions", require"luv.utils", require "luv.sessions", require "luv.fs", require "luv.webservers", require "luv.sessions"
local Object, Exception, Version = oop.Object, exceptions.Exception, utils.Version

module(...)

-- It's very dumbas algo, I know :), I will rewrite it soon
local function dropModel (model, models)
	model:setDb(db)
	-- Drop constraints
	local constraintModels, _, v = model:getConstraintModels()
	for _, v in ipairs(constraintModels) do
		local index = table.find(models, v)
		if  index then
			models[index] = nil
			dropModel(v, models)
		end
	end
	-- Drop self
	if not model:dropTables() then
		return false
	else
		return true
	end
end

-- It's the same, I know...
local function createModel (model, models)
	-- Create self
	if not model:createTables() then
		return false
	else
		return true
	end
	-- Create constraints
	local constraintModels, _, v = model:getConstraintModels()
	for _, v in ipairs(constraintModels) do
		local index = table.find(models, v)
		if index then
			models[index] = nil
			createModel(v, models)
		end
	end
end

local UrlConf = Object:extend{
	__tag = .....".UrlConf",
	init = function (self, wsApi)
		self.wsApi = wsApi
		self.uri = wsApi:getRequestHeader("REQUEST_URI") or ""
		local queryPos = string.find(self.uri, "?")
		if queryPos then
			self.uri = string.sub(self.uri, 1, queryPos-1)
		end
		self.tailUri = self.uri
		self.baseUri = ""
	end,
	getWsApi = function (self) return self.wsApi end;
	setWsApi = function (self, wsApi) self.wsApi = wsApi return self end;
	getCapture = function (self, pos)
		return self.captures[pos]
	end;
	getUri = function (self) return self.uri end;
	getTailUri = function (self) return self.tailUri end;
	getBaseUri = function (self) return self.baseUri end;
	execute = function (self, action)
		if type(action) == "string" then
			local result = dofile(action)
			return result and self:dispatch(result) or true
		elseif type(action) == "function" then
			return action(self)
		elseif type(action) == "table" then
			return self:dispatch(action)
		else
			Exception "Invalid action!":throw()
		end
	end,
	dispatch = function (self, urls)
		local _, item, action
		for _, item in pairs(urls) do
			if "string" == type(item[1]) then
				local res = {string.find(self.tailUri, item[1])}
				if nil ~= res[1] then
					local oldTailUri, oldBaseUri, oldCaptures = self.tailUri, self.baseUri, self.captures
					local tailUriLen = string.len(self.tailUri)
					self.baseUri = self.baseUri..string.sub(self.uri, 1, -tailUriLen+res[1]-2)
					self.tailUri = string.sub(self.tailUri, res[2]+1)
					self.captures = {}
					local i = 3
					for i = 3, #res do
						table.insert(self.captures, res[i])
					end
					if false ~= self:execute(item[2]) then
						return true
					end
				end
			elseif false == item[1] then
				action = item[2]
			end
		end
		if action then self:execute(action) return true end
		return false
	end
}

local Core = Object:extend{
	__tag = .....".Core",
	version = Version(0, 3, 0, "alpha"),
	-- Init
	init = function (self, wsApi)
		-- Init random seed
		local seed, i, str = os.time(), nil, tostring(tostring(self))
		for i = 1, string.len(str) do
			seed = seed + string.byte(str, i)
		end
		math.randomseed(seed)
		--
		self.wsApi = (wsApi or ws.Cgi()):setResponseHeader("X-Powered-By", "Luv/"..tostring(self.version))
		self.urlconf = UrlConf(self.wsApi)
	end,
	getWsApi = function (self) return self.wsApi end,
	setWsApi = function (self, wsApi) self.wsApi = wsApi return self end,
	getTemplater = function (self) return self.templater end,
	setTemplater = function (self, templater) self.templater = templater return self end,
	getSession = function (self) return self.session end,
	setSession = function (self, session) self.session = session return self end,
	getDsn = function (self) return self.dsn end,
	setDsn = function (self, dsn)
		self.dsn = dsn
		self.db = require "luv.db".Factory(dsn)
		require "luv.db.models".Model:setDb(self.db)
		self.db:setLogger(function (sql, result)
			self:debug(sql, "Database")
		end)
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
		local models, result, k, v = {}, true
		for k, v in ipairs(modelsList) do
			modelsList[k] = nil
			iterator(v, modelsList)
		end
		--return result
	end,
	dropModels = function (self, models)
		self:iterateModels(table.copy(models), dropModel)
	end,
	createModels = function (self, models)
		self:iterateModels(table.copy(models), createModel)
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
		self:assign{debugger=self.debugger or ""}
		return self.templater:fetch(template)
	end,
	display = function (self, template)
		self:assign{debugger=self.debugger or ""}
		return self.templater:display(template)
	end;
	-- Debugger
	getDebugger = function (self) return self.debugger end;
	setDebugger = function (self, debugger)
		self.debugger = debugger
		return self
	end;
	debug = function (self, ...)
		if self.debugger then
			self.debugger:debug(...)
		end
	end;
	info = function (self, ...)
		if self.debugger then
			self.debugger:info(...)
		end
	end;
	warn = function (self, ...)
		if self.debugger then
			self.debugger:warn(...)
		end
	end;
	error = function (self, ...)
		if self.debugger then
			self.debugger:error(...)
		end
	end;
}

local Struct = Object:extend{
	__tag = .....".Struct",
	init = function (self)
		self.errors = {}
	end,
	__index = function (self, field)
		if field == "pk" then return self:getPk():getValue() end
		local res = rawget(self, "fieldsByName")
		if res then
			res = res[field]
			if res then
				if res:isKindOf(require "luv.fields.references".ManyToMany) or res:isKindOf(require "luv.fields.references".OneToMany)then
					return res
				else
					return res:getValue()
				end
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
	-- Fields
	getField = function (self, field) return self.fieldsByName[field] end;
	getFields = function (self) return self.fields end;
	getFieldsByName = function (self) return self.fieldsByName end;
	getValues = function (self)
		local res = {}
		local k, v
		for k, v in pairs(self:getFieldsByName()) do
			res[k] = v:getValue()
		end
		return res
	end,
	setValues = function (self, values)
		local k, v
		for k, v in pairs(self:getFieldsByName()) do
			v:setValue(values[k])
		end
	end;
	addField = function (self, name, field)
		if not field:isKindOf(require "luv.fields".Field) then
			Exception "instance of Field expected!":throw()
		end
		field:setContainer(self)
		field:setName(name)
		table.insert(self.fields, field)
		self.fieldsByName[name] = field
		return self
	end;
	-- Validation & errors collect
	isValid = function (self)
		local _, v
		self:setErrors{}
		for _, v in ipairs(self:getFields()) do
			if not v:isValid() then
				local _, e for _, e in ipairs(v:getErrors()) do
					local label = v:getLabel()
					self:addError(string.gsub(e, "%%s", label and string.capitalize(label) or v:getName()))
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
}

local Widget = Object:extend{
	__tag = .....".Widget",
	render = Object.abstractMethod
}

local init = function (params)
	local core = Core(params.wsApi)
	core:setTemplater(require "luv.templaters.tamplier" (params.templatesDirs))
	core:setSession(sessions.Session(core:getWsApi(), sessions.SessionFile(params.sessionDir)))
	core:setDsn(params.dsn)
	core:setDebugger(params.debugger)
	return core
end

return {
	oop = oop,
	exceptions = exceptions,
	util = util,
	Core = Core,
	UrlConf = UrlConf,
	Struct = Struct,
	Widget = Widget,
	init = init
}
	
