local tonumber = tonumber
local Object, Exception, Debug = require"ProtOo", require"Exception", require"Debug"

module(...)

return Object:extend{
	__tag = "LazyQuerySet",

	init = function (self, select)
		self.select = select
	end,
	count = function (self)
		local result = self.select:fields("COUNT(*)"):exec()
		if not result then
			return nil
		end
		return tonumber(result[1]["COUNT(*)"])
	end
}
