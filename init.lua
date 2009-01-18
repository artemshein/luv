local pairs, require, select, unpack = pairs, require, select, unpack
local _G = _G

local import = function (self, ...)
	local i
	local res = {}
	for i = 1, select("#", ...) do
		table.insert(res, require(self.module.."."..select(i, ...)))
	end
	return unpack(res)
end

from = function (module)
	return {module = module, import = import}
end

local Object, Exception, Version, Table, Namespace, String, File = from"Luv":import("Object", "Exception", "Version", "Table", "Namespace", "String", "File")

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
		self.urlconf = require"Luv.UrlConf"(wsApi)
	end,
	getDsn = function (self) return self.dsn end,
	setDsn = function (self, dsn)
		self.dsn = dsn
		self.db = require"Luv.Db".Factory:connect(dsn)
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



return Namespace:extend{
	__tag = ...,

	ns = ...,
	Object = Object,
	Exception = Exception,
	Version = Version,
	Table = Table,
	Namespace = Namespace,
	Core = Core
}
	
