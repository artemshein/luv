local Object = require "luv.oop".Object

module(...)

local Migration = Object:extend{
	__tag = .....".Migration";
	getDb = function (self) return self._db end;
	setDb = function (self) self._db = db return self end;
	up = function (self)
		return self._db:query(self:getUpSql())
	end;
	down = function (self)
		return self._db:query(self:getDownSql())
	end;
	getUpSql = Object.abstractMethod;
	getDownSql = Object.abstractMethod;
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

return {}
