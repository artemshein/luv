local table = require "luv.table"
local string = require "luv.string"
local dev = require "luv.dev"
local pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile = pairs, require, select, unpack, type, rawget, rawset, math, os, tostring, io, ipairs, dofile
local tr, error = tr, error
local oop, exceptions, sessions, fs, ws, sessions, utils = require"luv.oop", require"luv.exceptions", require "luv.sessions", require "luv.fs", require "luv.webservers", require "luv.sessions", require "luv.utils"
local Object, Exception, Version = oop.Object, exceptions.Exception, utils.Version
local crypt, backend = require "luv.crypt", require "luv.cache.backend"
local Memory, NamespaceWrapper, TagEmuWrapper = backend.Memory, backend.NamespaceWrapper, backend.TagEmuWrapper
local Slot = require "luv.cache.frontend".Slot

module(...)

local MODULE = (...)

local UrlConf = Object:extend{
	__tag = .....".UrlConf";
	request = Object.property;
	uri = Object.property;
	tailUri = Object.property;
	baseUri = Object.property;
	captures = Object.property;
	init = function (self, request)
		self:request(request)
		self:uri(request:header "REQUEST_URI" or "")
		local queryPos = string.find(self._uri, "?")
		if queryPos then
			self:uri(string.sub(self._uri, 1, queryPos-1))
		end
		self:tailUri(self._uri)
		self:baseUri""
		self:captures{}
	end;
	capture = function (self, pos)
		return self._captures[pos]
	end;
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
		return Slot.init(self, luv:cacher(), tostring(crypt.Md5(template..string.serialize(params))), 60*60)
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
	_version = Version(0, 11, 0, "alpha");
	version = Object.property;
	urlConf = Object.property;
	wsApi = Object.property;
	templater = Object.property;
	session = Object.property;
	db = Object.property;
	profiler = Object.property;
	debugger = Object.property;
	i18n = Object.property;
	-- Init
	init = function (self, wsApi)
		self:profiler(dev.Profiler())
		self:beginProfiling "Luv"
		--
		self:wsApi(wsApi:responseHeader("X-Powered-By", "Luv/"..tostring(self.version)))
		self:urlConf(UrlConf(ws.HttpRequest(self:wsApi())))
		self:cacher(TagEmuWrapper(Memory()))
	end;
	-- Database
	dsn = function (self, ...)
		if select("#", ...) > 0 then
			self._dsn = (select(1, ...))
			self:db(require "luv.db".Factory(self._dsn))
			require "luv.db.models".Model:db(self:db())
			self:db():logger(function (sql, result)
				--io.write("\n", sql, "\n")
				self:debug(sql, "Database")
			end)
			return self
		else
			return self._dsn
		end
	end;
	beginTransaction = function (self) return self._db:beginTransaction() end;
	commit = function (self) return self._db:commit() end;
	rollback = function (self) return self._db:rollback() end;
	-- Web-server
	requestHeader = function (self, ...) return self:wsApi():requestHeader(...) end;
	responseHeader = function (self, ...) self:wsApi():responseHeader(...) return self end;
	responseCode = function (self, ...) self:wsApi():responseCode(...) return self end;
	sendHeaders = function (self, ...) self:wsApi():sendHeaders(...) return self end;
	get = function (self, ...) return self:wsApi():get(...) end;
	getData = function (self) return self:wsApi():getData() end;
	post = function (self, ...) return self:wsApi():post(...) end;
	postData = function (self) return self:wsApi():postData() end;
	cookie = function (self, ...)
		if select("#", ...) > 0 then
			self:wsApi():cookie(...)
			return self
		else
			return self:wsApi():cookie()
		end
	end;
	cookies = function (self) return self:wsApi():cookies() end;
	-- URL conf
	dispatch = function (self, urlconf) return self:urlConf():dispatch(urlconf) end;
	-- Templater
	addTemplatesDir = function (self, templatesDir)
		self:templater():addTemplatesDir(templatesDir)
		return self
	end;
	assign = function (self, ...)
		self:templater():assign(...)
		return self
	end;
	fetchString = function (self, template)
		self:flush()
		return self:templater():fetchString(template)
	end;
	fetch = function (self, template)
		self:flush()
		return self:templater():fetch(template)
	end;
	displayString = function (self, template)
		self:flush()
		return self:templater():displayString(template)
	end;
	display = function (self, template)
		self:flush()
		return self:templater():display(template)
	end;
	flush = function (self)
		self:endProfiling"Luv"
		for section, info in pairs(self:profiler():stat()) do
			self:info(section.." was executed "..tostring(info.count).." times and takes "..tostring(info.total).." secs", "Profiler")
		end
		self:assign{debugger=self:debugger() or ""}
	end;
	-- Profiler
	beginProfiling = function (self, section) self:profiler():beginSection(section) return self end;
	endProfiling = function (self, section) self:profiler():endSection(section) return self end;
	-- Debugger
	debug = function (self, ...) return self._debugger and self._debugger:debug(...) or self end;
	info = function (self, ...) return self._debugger and self._debugger:info(...) or self end;
	warn = function (self, ...) return self._debugger and self._debugger:warn(...) or self end;
	error = function (self, ...) return self._debugger and self._debugger:error(...) or self end;
	-- Caching
	cacher = function (self, ...)
		if select("#", ...) > 0 then
			self._cacher = cacher
			require "luv.db.models".Model:cacher(cacher)
			return self
		else
			return self._cacher
		end
	end;
	createTemplateSlot = function (self, template, params)
		return TemplateSlot(self, template, params)
	end;
	--[[createModelSlot = function (self, model)
		return require "luv.db.models".ModelSlot(self:getCacher(), model)
	end;]]
	createModelTag = function (self, model)
		return require "luv.db.models".ModelTag(self:cacher(), model)
	end;
	-- I18n
	tr = function (self, str) return self._i18n:tr(str) or str end;
}

local Struct = Object:extend{
	__tag = .....".Struct";
	errors = Object.property;
	msgs = Object.property;
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
				local references = require "luv.fields.references"
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
		if not self._fields then
			Exception "fields required"
		end
		if not field:isA(require "luv.fields".Field) then
			Exception "instance of Field expected"
		end
		field:container(self)
		field:name(name)
		self._fields[name] = field
		return self
	end;
	field = function (self, field) return self._fields[field] or nil end;
	fields = function (self, ...)
		if select("#", ...) > 0 then
			self._fields = {}
			for name, f in pairs((select(1, ...))) do
				self:addField(name, f)
			end
			return self
		else
			return self._fields
		end
	end;
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
				if "table" == type(value) and value.isA and value:isA(require "luv.fields.references".OneToMany) then
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
					self:addError(string.gsub(e, "%%s", label and string.capitalize(tr(label)) or string.capitalize(tr(name))))
				end
			end
		end
		return table.isEmpty(self:errors())
	end;
	addError = function (self, error) table.insert(self._errors, error) return self end;
	addErrors = function (self, errors)
		for _, error in ipairs(errors) do
			self:addError(error)
		end
	end;
	addMsg = function (self, msg) table.insert(self._msgs, msg) return self end;
	addMsgs = function (self, msgs)
		for _, msg in ipairs(msgs) do
			self:addMsg(msg)
		end
		return self
	end;
}

local Widget = Object:extend{
	__tag = .....".Widget";
	render = Object.abstractMethod;
}

local init = function (params)
	local core = Core(params.wsApi or ws.Cgi(params.tmpDir))
	core:templater(params.templater or require "luv.templaters".Tamplier (params.templatesDirs))
	core:session(sessions.Session(core:wsApi(), sessions.SessionFile(params.sessionDir)))
	core:dsn(params.dsn)
	core:debugger(params.debugger)
	if params.cacher then core:cacher(params.cacher) end
	if params.i18n then core:i18n(params.i18n) end
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
	oop=oop;exceptions=exceptions;util=util;Core=Core;UrlConf=UrlConf;
	Struct=Struct;Widget=Widget;init=init;getObjectOr404=getObjectOr404;
}
	
