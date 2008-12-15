local Struct, Table = require"Struct", require"Table"
local rawget, rawset, getmetatable = rawget, rawset, getmetatable

module(...)

local Model = Struct:extend{
	__tag = "Models.Model"
}

return Model