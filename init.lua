require"luv.table"
require"luv.string"
require"luv.debug"
local pairs, require, select, unpack, string, table, debug, type, rawget, rawset = pairs, require, select, unpack, string, table, debug, type, rawget, rawset
local _G = _G
local oop, exceptions, utils = require"luv.oop", require"luv.exceptions", require"luv.utils"
local Object, Exception, Version = oop.Object, exceptions.Exception, utils.Version

module(...)

local function dropModel (db, modelName, models)
	local model = require(modelName)
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
	local model = require(modelName)
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

local Core = Object:extend{
	__tag = .....".Core",
	version = Version(0, 3, 0, "dev"),
	-- Init
	init = function (self, wsApi)
		self.wsApi = wsApi
		self.urlconf = require"luv".UrlConf(wsApi)
	end,
	getDsn = function (self) return self.dsn end,
	setDsn = function (self, dsn)
		self.dsn = dsn
		self.db = require"luv.db".Factory(dsn)
		return self
	end,
	getDb = function (self) return self.db end,
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
	dropModels = function (self, modelsList)
		return self:iterateModels(modelsList, dropModel)
	end,
	createModels = function (self, modelsList)
		return self:iterateModels(modelsList, createModel)
	end
}

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
	dispatch = function (self, urls)
		for expr, script in pairs(urls) do
			local res = {string.find(self.uri, expr)}
			if nil ~= res[1] then
				self.uri = string.sub(self.uri, res[2]+1)
				self.captures = {}
				local i = 3
				for i = 3, #res do
					table.insert(self.captures, res[i])
				end
				if type(script) == "string" then
					dofile(script)
				elseif type(script) == "function" then
					script(self)
				else
					Exception"Invalid action!":throw()
				end
				return true
			end
		end
		return false
	end
}

local Struct = Object:extend{
	__tag = .....".Struct",
	__index = function (self, field)
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
	validate = function (self)
		local k, v
		for k, v in pairs(self.fields) do
			if not v:validate() then
				return false
			end
		end
		return true
	end,
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
	
