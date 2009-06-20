local type, ipairs, tostring, tonumber = type, ipairs, tostring, tonumber
local require, loadstring, assert = require, loadstring, assert
local string = require "luv.string"
local Object = require "luv.oop".Object
local fs = require "luv.fs"
local models = require "luv.db.models"
local fields = require "luv.fields"
local Exception = require "luv.exceptions".Exception

module(...)

local MigrationLog = models.Model:extend{
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

local MigrationManager = Object:extend{
	__tag = .....".MigrationManager";
	init = function (self, db, scriptsDir)
		self._db = db
		self._scriptsDir = scriptsDir
		if not self._scriptsDir.isKindOf or not self._scriptsDir:isKindOf(fs.Dir) then
			self._scriptsDir = fs.Dir(self._scriptsDir)
		end
		self._lastMigration = 0
		self._migrations = {}
		for i, file in ipairs(self._scriptsDir:getFiles()) do
			local name = file:getName()
			if string.endsWith(name, ".lua") then
				local begPos, _, capture = string.find(name, "^([0-9]+)")
				if begPos then
					local num = tonumber(capture)
					self._migrations[num] = file
					if self._lastMigration < num then
						self._lastMigration = num
					end
				end
			end
		end
	end;
	getCurrentMigration = function (self)
		if not self._currentMigration then
			self._currentMigration = self._db:SelectCell "to":from(MigrationLog:getTableName()):order "-datetime"() or 0
		end
		return self._currentMigration
	end;
	getLastMigration = function (self)
		return self._lastMigration
	end;
	_log = function (self, from, to)
		self._db:InsertRow():into(MigrationLog:getTableName()):set("?# = ?d", "from", from):set("?# = ?d", "to", to)()
	end;
	_loadMigration = function (self, num)
		if self._migrations[num] then
			return assert(loadstring(self._migrations[num]:openReadAndClose "*a"))()(self._db)
		end
	end;
	_apply = function (self, from, to)
		local iter = 1
		if from == to then
			Exception "migrations from and to should be different"
		elseif from > to then
			iter = -1
		end
		for i = from+iter, to, iter do
			if not self._migrations[i] then
				Exception("migration "..i.." not founded")
			end
		end
		for i = from+iter, to, iter do
			local migration = self:_loadMigration(i)
			if iter > 0 then
				if not migration or not migration:up() then
					-- Try to rollback
					for j = i-1, from+iter, -1 do
						migration = self:_loadMigration(j)
						if not migration or not migration:down() then
							Exception("migration fails to apply from "..from.." to "..to.." and fails to rollback from "..j.." to "..(j-1))
						end
					end
					return false, ("fails to apply up from "..(i-1).." to "..i)
				end
			else
				if not migration or not migration:down() then
					-- Try to rollback
					for j = i+1, from+iter do
						migration = self:_loadMigration(j)
						if not migration or not migration:up() then
							Exception("migration fails to apply from "..from.." to "..to.." and fails to rollback from "..j.." to "..(j+1))
						end
					end
					return false, ("fails to apply down from "..i.." to "..(i-1))
				end
			end
		end
		self._currentMigration = to
		self:_log(from, to)
		return true
	end;
	up = function (self)
		if self:getCurrentMigration() >= self:getLastMigration() then
			Exception "last migration already reached up"
		end
		return self:_apply(self:getCurrentMigration(), self:getCurrentMigration()+1)
	end;
	down = function (self)
		if self:getCurrentMigration() <= 0 then
			Exception "migration 0 already reached down"
		end
		return self:_apply(self:getCurrentMigration(), self:getCurrentMigration()-1)
	end;
	upTo = function (self, to)
		if self:getCurrentMigration() >= self:getLastMigration() then
			Exception "last migration already reached up"
		elseif self:getCurrentMigration() >= to then
			Exception("migration "..to.." already reached up")
		elseif to > self:getLastMigration() then
			Exception("migration "..to.." can't be reached up")
		end
		return self:_apply(self:getCurrentMigration(), to)
	end;
	downTo = function (self, to)
		if self:getCurrentMigration() <= 0 then
			Exception "migration 0 already reached down"
		elseif self:getCurrentMigration() <= to then
			Exception("migration "..to.." already reached down")
		elseif to <= 0 then
			Exception("migration "..to.." can't be reached down")
		end
		return self:_apply(self:getCurrentMigration(), to)
	end;
	allUp = function (self)
		if self:getCurrentMigration() >= self:getLastMigration() then
			Exception "last migration already reached up"
		end
		return self:_apply(self:getCurrentMigration(), self:getLastMigration())
	end;
	allDown = function (self)
		if self:getCurrentMigration() <= 0 then
			Exception "migration 0 already reached down"
		end
		return self:_apply(self:getCurrentMigration(), 0)
	end;
}

return {
	models={MigrationLog=MigrationLog};
	Migration=Migration;
	MigrationManager=MigrationManager;
}
