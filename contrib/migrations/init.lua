local Object = require "luv.oop".Object
local fs = require "luv.fs"

module(...)

local MigrationLog = Model:extend{
	__tag = .....".MigrationLog";
	Meta = {labels={"migration log";"migration logs"}};
	from = fields.Int{required=true};
	to = fields.Int{required=true};
	datetime = fields.Datetime{autonow=true};
}

local Migration = Object:extend{
	__tag = .....".Migration";
	getDb = function (self) return self._db end;
	setDb = function (self) self._db = db return self end;
	up = Object.abstractMethod;
	down = Object.abstractMethod;
}

local Init = Migration:extend{
	__tag = .....".Init";
	init = function (self, models)
		self._models = models
	end;
}

local AddColumn = Migration:extend{
	__tag = .....".AddColumn";
	init = function (self, model, fieldName, field)
		self._model = model
		self._fieldName = fieldName
		self._field = field
	end;
}

local MigrationManager = Object:extend{
	__tag = .....".MigrationManager";
	init = function (self, db, scriptsDir)
		self._db = db
		self._scriptsDir = scriptsDir
		if "string" == type(self._scriptsDir) then
			self._scriptsDir = fs.Directory(self._scriptsDir)
		end
		self._migrations = {}
		for i, file in ipairs(self._scriptsDir:getFiles()) do
			local num = tostring(file:getName())
			if num then
				self._migrations[num] = file
			end
		end
	end;
	_log = function (self, from, to)
		self._db:InsertRow():into(MigrationLog:getTableName()):set("?# = ?d", "from", from):set("?# = ?d", "to", to):exec()
	end;
	_apply = function (self, from, to)
		local iter = 1
		if from == to then
			Exception "migrations from and to should be different"
		elseif from > to then
			iter = -1
		end
		for i = from, to, iter do
			if not self._migrations[i] then
				Exception("migration "..i.." not founded")
			end
		end
		for i = from, to, iter do
			if iter > 0 then
				if not self:_loadMigration(i):up() then
					-- Try to rollback
					for j = i-1, from, -1 do
						if not self:_loadMigration(j):down() then
							Exception("migration fails to apply from "..from.." to "..to.." and fails to rollback from "..j.." to "..(j-1))
						end
					end
					return false, ("fails to apply from "..i.." to "..(i+1))
				end
			else
				if not self:_loadMigration(i):down() then
					-- Try to rollback
					for j = i+1, from do
						if not self:_loadMigration(j):up() then
							Exception("migration fails to apply from "..from.." to "..to.." and fails to rollback from "..j.." to "..(j+1))
						end
					end
					return false, ("fails to apply from "..i.." to "..(i-1))
				end
			end
		end
		self:_log(from, to)
		return true
	end;
	up =
	down =
	upTo =
	downTo =
	allUp =
	allDown =
}

return {
	models = {};
}
