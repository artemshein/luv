local table = require "luv.table"
local string = require "luv.string"
local dev = require "luv.dev"
local pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile = pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile
local _G, error = _G, error
local oop, exceptions, sessions, fs, ws, sessions, utils = require"luv.oop", require"luv.exceptions", require "luv.sessions", require "luv.fs", require "luv.webservers", require "luv.sessions", require "luv.utils"
local Object, Exception, Version = oop.Object, exceptions.Exception, utils.Version
local crypt, backend = require "luv.crypt", require "luv.cache.backend"
local Memory, NamespaceWrapper, TagEmuWrapper = backend.Memory, backend.NamespaceWrapper, backend.TagEmuWrapper
local Slot = require "luv.cache.frontend".Slot

module(...)

local MODULE = (...)

local UrlConf = Object:extend{
	__tag = .....".UrlConf";
	init = function (self, request)
		self._request = request
		self._uri = request:getHeader "REQUEST_URI" or ""
		local queryPos = string.find(self._uri, "?")
		if queryPos then
			self._uri = string.sub(self._uri, 1, queryPos-1)
		end
		self._tailUri = self._uri
		self._baseUri = ""
		self._captures = {}
	end;
	getRequest = function (self) return self._request end;
	setRequest = function (self, request) self._request = request return self end;
	getCapture = function (self, pos)
		return self._captures[pos]
	end;
	getUri = function (self) return self._uri end;
	getTailUri = function (self) return self._tailUri end;
	getBaseUri = function (self) return self._baseUri end;
	execute = function (self, action)
		if type(action) == "string" then
			local result = dofile(action)
			return result and self:dispatch(result) or true
		elseif type(action) == "function" then
			return action(self, unpack(self._captures))
		elseif type(action) == "table" then
			return self:dispatch(action)
		else
			Exception "invalid action"
		end
	end;
	dispatch = function (self, urls)
		local action
		if "string" == type(urls) then
			return self:dispatch(dofile(urls))
		end
		for _, item in pairs(urls) do
			if "string" == type(item[1]) then
				local res = {string.find(self._tailUri, item[1])}
				if nil ~= res[1] then
					local oldTailUri, oldBaseUri, oldCaptures = self._tailUri, self._baseUri, self._captures
					local tailUriLen = string.len(self._tailUri)
					self._baseUri = self._baseUri..string.sub(self._uri, 1, -tailUriLen+res[1]-2)
					self._tailUri = string.sub(self._tailUri, res[2]+1)
					self.captures = {}
					for i = 3, #res do
						table.insert(self._captures, res[i])
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
	end;
}

local TemplateSlot = Slot:extend{
	__tag = .....".TemplateSlot";
	init = function (self, luv, template, params)
		self._luv = luv
		self._template = template
		return Slot.init(self, luv:getCacher(), tostring(crypt.Md5(template..string.serialize(params))), 60*60)
	end;
	displayCached = function (self)
		local res = self:get()
		if not res then return false end
		io.write(res)
		return true
	end;
	display = function (self)
		self.luv:info("Template cache date "..os.date(), "Cacher")
		local res = self.luv:fetch(self._template)
		self:set(res)
		io.write(res)
		return self
	end;
}

local Core = Object:extend{
	__tag = .....".Core";
	version = Version(0, 10, 0, "alpha");
	-- Init
	init = function (self, wsApi)
		self:setProfiler(dev.Profiler())
		self:beginProfiling "Luv"
		--
		self:setWsApi(wsApi:setResponseHeader("X-Powered-By", "Luv/"..tostring(self.version)))
		self._urlconf = UrlConf(ws.HttpRequest(self:getWsApi()))
		self:setCacher(TagEmuWrapper(Memory()))
	end;
	getWsApi = function (self) return self._wsApi end,
	setWsApi = function (self, wsApi) self._wsApi = wsApi return self end,
	getTemplater = function (self) return self._templater end,
	setTemplater = function (self, templater) self._templater = templater return self end,
	getSession = function (self) return self._session end,
	setSession = function (self, session) self._session = session return self end,
	-- Database
	getDsn = function (self) return self._dsn end,
	setDsn = function (self, dsn)
		self._dsn = dsn
		self._db = require "luv.db".Factory(dsn)
		require "luv.db.models".Model:setDb(self._db)
		self._db:setLogger(function (sql, result)
			--io.write(sql, "<br />")
			self:debug(sql, "Database")
		end)
		return self
	end,
	getDb = function (self) return self._db end,
	beginTransaction = function (self) return self._db:beginTransaction() end;
	commit = function (self) return self._db:commit() end;
	rollback = function (self) return self._db:rollback() end;
	-- Web-server
	getRequestHeader = function (self, ...) return self._wsApi:getRequestHeader(...) end,
	setResponseHeader = function (self, ...) self._wsApi:setResponseHeader(...) return self end,
	setResponseCode = function (self, ...) self._wsApi:setResponseCode(...) return self end;
	sendHeaders = function (self, ...) self._wsApi:sendHeaders(...) return self end;
	getGet = function (self, name) return self._wsApi:getGet(name) end,
	getGetData = function (self) return self._wsApi:getGetData() end,
	getPost = function (self, name) return self._wsApi:getPost(name) end,
	getPostData = function (self) return self._wsApi:getPostData() end,
	getCookie = function (self, name) return self.wsApi:getCookie(name) end,
	setCookie = function (self, ...) self._wsApi:setCookie(...) return self end,
	getCookies = function (self) return self._wsApi:getCookies() end,
	getSession = function (self) return self._session end,
	setSession = function (self, session) self._session = session return self end,
	-- URL conf
	dispatch = function (self, urlconf) return self._urlconf:dispatch(urlconf) end,
	-- Templater
	addTemplatesDir = function (self, templatesDir)
		self._templater:addTemplatesDir(templatesDir)
		return self
	end,
	assign = function (self, ...)
		self._templater:assign(...)
		return self
	end;
	fetchString = function (self, template)
		self:flush()
		return self._templater:fetchString(template)
	end;
	fetch = function (self, template)
		self:flush()
		return self._templater:fetch(template)
	end;
	displayString = function (self, template)
		self:flush()
		return self._templater:displayString(template)
	end;
	display = function (self, template)
		self:flush()
		return self._templater:display(template)
	end;
	flush = function (self)
		self:endProfiling("Luv")
		for section, info in pairs(self:getProfiler():getStat()) do
			self:info(section.." was executed "..tostring(info.count).." times and takes "..tostring(info.total).." secs", "Profiler")
		end
		self:assign{debugger=self._debugger or ""}
	end;
	-- Profiler
	getProfiler = function (self) return self._profiler end;
	setProfiler = function (self, profiler) self._profiler = profiler return self end;
	beginProfiling = function (self, section) self._profiler:beginSection(section) return self end;
	endProfiling = function (self, section) self._profiler:endSection(section) return self end;
	-- Debugger
	getDebugger = function (self) return self._debugger end;
	setDebugger = function (self, debugger)
		self._debugger = debugger
		return self
	end;
	debug = function (self, ...) return self._debugger and self._debugger:debug(...) or self end;
	info = function (self, ...) return self._debugger and self._debugger:info(...) or self end;
	warn = function (self, ...) return self._debugger and self._debugger:warn(...) or self end;
	error = function (self, ...) return self._debugger and self._debugger:error(...) or self end;
	-- Caching
	getCacher = function (self) return self._cacher end;
	setCacher = function (self, cacher)
		self._cacher = cacher
		require "luv.db.models".Model:setCacher(cacher)
		return self
	end;
	createTemplateSlot = function (self, template, params)
		return TemplateSlot(self, template, params)
	end;
	--[[createModelSlot = function (self, model)
		return require "luv.db.models".ModelSlot(self:getCacher(), model)
	end;]]
	createModelTag = function (self, model)
		return require "luv.db.models".ModelTag(self:getCacher(), model)
	end;
	-- I18n
	getI18n = function (self) return self._i18n end;
	setI18n = function (self, i18n) self._i18n = i18n return self end;
	tr = function (self, str) return self._i18n:tr(str) or str end;
}

local Struct = Object:extend{
	__tag = .....".Struct",
	init = function (self)
		self._msgs = {}
		self._errors = {}
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
	getField = function (self, field) return self.fieldsByName and self.fieldsByName[field] or nil end;
	getFields = function (self) return self.fields end;
	getFieldsByName = function (self) return self.fieldsByName end;
	getValues = function (self)
		local res = {}
		for k, v in pairs(self:getFieldsByName()) do
			local value = v:getValue()
			if "table" == type(value) and value.isKindOf and value:isKindOf(require "luv.fields.references".OneToMany) then
				res[k] = value:all():getValue()
			else
				res[k] = v:getValue()
			end
		end
		return res
	end,
	setValues = function (self, values)
		for k, v in pairs(self:getFieldsByName()) do
			v:setValue(values[k])
		end
		return self
	end;
	addField = function (self, name, field)
		if not field:isKindOf(require "luv.fields".Field) then
			Exception "instance of Field expected!"
		end
		field:setContainer(self)
		field:setName(name)
		table.insert(self.fields, field)
		self.fieldsByName[name] = field
		return self
	end;
	-- Validation & errors collect
	isValid = function (self)
		self:setErrors{}
		for _, v in ipairs(self:getFields()) do
			if not v:isValid() then
				for _, e in ipairs(v:getErrors()) do
					local label = v:getLabel()
					self:addError(string.gsub(_G.tr(e), "%%s", label and string.capitalize(_G.tr(label)) or string.capitalize(_G.tr(v:getName()))))
				end
			end
		end
		return table.isEmpty(self:getErrors())
	end,
	addError = function (self, error) table.insert(self._errors, error) return self end,
	setErrors = function (self, errors) self._errors = errors return self end,
	addErrors = function (self, errors)
		for _, v in ipairs(errors) do
			table.insert(self._errors, v)
		end
	end,
	getErrors = function (self) return self._errors end,
	getErrorsCount = function (self) return table.maxn(self._errors) end,
	addMsg = function (self, msg) table.insert(self._msgs, msg) return self end;
	setMsgs = function (self, msgs) self._msgs = msgs return self end;
	addMsgs = function (self, msgs)
		for _, msg in ipairs(msgs) do
			self:addMsg(msg)
		end
		return self
	end;
	getMsgs = function (self) return self._msgs end;
}

local Widget = Object:extend{
	__tag = .....".Widget";
	render = Object.abstractMethod;
}

local init = function (params)
	local core = Core(params.wsApi or ws.Cgi(params.tmpDir))
	core:setTemplater(params.templater or require "luv.templaters".Tamplier (params.templatesDirs))
	core:setSession(sessions.Session(core:getWsApi(), sessions.SessionFile(params.sessionDir)))
	core:setDsn(params.dsn)
	core:setDebugger(params.debugger)
	if params.cacher then core:setCacher(params.cacher) end
	if params.i18n then core:setI18n(params.i18n) end
	return core
end

local getObjectOr404 = function (model, conditions)
	local obj = model:find(conditions)
	if not obj then
		ws.Http404()
	end
	return obj
end

(function () -- Init random seed
	local seed, i, str = os.time(), nil, tostring(tostring(MODULE))
	for i = 1, string.len(str) do
		seed = seed + string.byte(str, i)
	end
	math.randomseed(seed)
end)() -- Excecute it imediately

return {
	oop = oop,
	exceptions = exceptions,
	util = util,
	Core = Core,
	UrlConf = UrlConf,
	Struct = Struct,
	Widget = Widget,
	init = init;getObjectOr404=getObjectOr404;
}
	
