local Hash, Filter = require"Crypt.Hash", require"datafilter"

module(...)

return Hash:extend{
	__tag = "Crypt.Md5",

	init = function (self, msg)
		self.hash = Filter.md5(msg)
	end,
	getHash = function (self)
		return self.hash
	end,
	__tostring = function (self)
		return Filter.hex_lower(self.hash)
	end
}
