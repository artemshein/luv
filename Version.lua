local Object = require"Luv.Object"

module(...)

return Object:extend{
	__tag = ...,

	minor = 0,
	patch = 0,
	state = "stable",
	
	init = function (self, major, minor, patch, state, rev, codename)
		self.major = major
		self.minor = minor
		self.patch = patch
		if state then
			self.state = state
		end
		self.rev = rev
		self.codename = codename
	end,
	
	full = function (self)
		local res = self.major.."."..self.minor
		if 0 ~= self.patch then
			res = res.."."..self.patch
		end
		if "stable" ~= self.state then
			res = res..self.state
		end
		if self.rev then
			res = res.." rev"..self.rev
		end
		if self.codename then
			res = res.." "..self.codename
		end
		return res
	end
}
