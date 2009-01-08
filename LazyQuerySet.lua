local tonumber, pairs, type, rawget, getmetatable = tonumber, pairs, type, rawget, getmetatable
local Table, String, Object, Exception, Debug = require"Table", require"String", require"ProtOo", require"Exception", require"Debug"

module(...)

return Object:extend{
	__tag = "LazyQuerySet",

	init = function (self, model)
		self.model = model
		self.db = model:getDb()
		self.evaluated = false
		self.filters = {}
		self.excludes = {}
		getmetatable(self).__index = function (self, field)
			local res = self.parent[field]
			if res then
				return res
			end
			if not self.evaluated then
				self:evaluate()
				return self.values[field]
			end
			return nil
		end
	end,
	filter = function (self, filters)
		if type(filters) == "table" then
			Table.insert(self.filters, filters)
		else
			Table.insert(self.filters, {filters})
		end
		return self
	end,
	exclude = function (self, excludes)
		if type(excludes) == "table" then
			Table.insert(self.excludes, excludes)
		else
			Table.insert(self.excludes, {excludes})
		end
		return self
	end,
	applyFilterOrExclude = function (self, filter, s)
		local filTbl, k, v = {}
		for k, v in pairs(filter) do
			local op = "="
			if type(k) == "number" then
				k = self.model:getPkName()
			end
			if String.find(k, "__") then
				local vals = String.explode(k, "__")
				local name, op = vals[1], vals[2]
				if op == "exact" then
					Table.insert(filTbl, self.db:processPlaceholders("?#="..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "lt" then
					Table.insert(filTbl, self.db:processPlaceholders("?#<"..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "lte" then
					Table.insert(filTbl, self.db:processPlaceholders("?#<="..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "gt" then
					Table.insert(filTbl, self.db:processPlaceholders("?#>"..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "gte" then
					Table.insert(filTbl, self.db:processPlaceholders("?#>="..self.model:getFieldPlaceholder(self.model:getField(name)), name, v))
				elseif op == "in" then
					Table.insert(filTbl, self.db:processPlaceholders("?# IN (?a)", name, v))
				elseif op == "beginswith" then
					Table.insert(filTbl, self.db:processPlaceholders("?# LIKE ?", name, v.."%"))
				elseif op == "endswith" then
					Table.insert(filTbl, self.db:processPlaceholders("?# LIKE ?", name, "%"..v))
				elseif op == "contains" then
					Table.insert(filTbl, self.db:processPlaceholders("?# LIKE ?", name, "%"..v.."%"))
				else
					Exception:new("Operation "..op.." not supported!"):throw()
				end
			else
				Table.insert(filTbl, self.db:processPlaceholders("?#="..self.model:getFieldPlaceholder(self.model:getField(k)), k, v))
			end
		end
		return Table.join(filTbl, ") AND (")
	end,
	applyFiltersAndExcludes = function (self, s)
		local _, k, v, res
		for _, v in pairs(self.filters) do
			res = self:applyFilterOrExclude(v, s)
			if res ~= "" then
				s:where(res)
			end
		end
		for _, v in pairs(self.excludes) do
			res = self:applyFilterOrExclude(v, s)
			if res ~= "" then
				s:where("NOT ("..res..")")
			end
		end
		return s
	end,
	count = function (self)
		local s = self.db:selectCell("COUNT(*)"):from(self.model:getTableName())
		self:applyFiltersAndExcludes(s)
		return tonumber(s:exec())
	end,
	delete = function (self)
		local s = self.db:delete():from(self.model:getTableName())
		self:applyFiltersAndExcludes(s)
		return s:exec()
	end,
	evaluate = function (self)
		self.evaluated = true
		local s = self.db:select():from(self.model:getTableName())
		self:applyFiltersAndExcludes(s)
		local _, v, obj = {}
		self.values = {}
		for _, v in pairs(s:exec()) do
			obj = self.model:new(v)
			self.values[obj:getPk():getValue()] = obj
		end
	end,
	pairs = function (self)
		if not self.evaluated then
			self:evaluate()
		end
		return pairs(self.values)
	end
}
