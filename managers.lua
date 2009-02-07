local oop = require "luv.oop"
local Object = oop.Object

module(...)

local Model = Object:extend{
	__tag = .....".Model",
	getModel = function (self) return self.model end
}

return {
	Model = Model
}
