module(..., package.seeall)

local Object = {
	init = function (self)	end,
	extend = function (self, tbl)
		local newObj = tbl or {}
		newObj.parent = self
		setmetatable(newObj, { __index = self })
		return newObj
	end,
	new = function (self, ...)
		local newObj = {}
		newObj.parent = self
		setmetatable(newObj, { __index = self })
		newObj:init(...)
		return newObj
	end,
	isKindOf = function (self, obj)
		if obj and (self == obj or (self.parent and (self.parent):isKindOf(obj))) then
			return true
		end
		return false
	end,
	abstractMethod = function ()
		error"Method must be implemented first!"
	end
}

return Object