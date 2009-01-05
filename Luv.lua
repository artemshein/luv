local pairs, require = pairs, require
local Object, Exception = require"ProtOo", require"Exception"

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
	if not model:drop() then
		return false
	else
		return true
	end
end

local function createModel (db, modelName, models)
	local model = require(modelName)
	model:setDb(db)
	-- Create self
	if not model:create() then
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

return Object:extend{
	__tag = "Luv",

	-- Init
	init = function (self)
		self.cgi = require"Cgi":new()
		self.urlconf = require"UrlConf":new()
	end,
	getDsn = function (self) return self.dsn end,
	setDsn = function (self, dsn)
		self.dsn = dsn
		self.db = require"Database.Factory":connect(dsn)
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
