require "luv.debug"
local os, table, pairs, ipairs, io, debug, tostring, type = os, table, pairs, ipairs, io, debug, tostring, type
local Object = require "luv.oop".Object
local json = require "luv.utils.json"

module(...)

local Debugger = Object:extend{
	__tag = .....".Debugger";
	debug = Object.abstractMethod;
	info = Object.abstractMethod;
	warn = Object.abstractMethod;
	error = Object.abstractMethod;
	flush = Object.abstractMethod;
}

local Fire = Debugger:extend{
	__tag = .....".Fire";
	defaultSectionName = "Default section";
	init = function (self)
		self.msgs = {}
	end;
	debug = function (self, msg, section)
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="log";msg=msg;time=os.clock()})
	end;
	info = function (self, msg, section)
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="info";msg=msg;time=os.clock()})
	end;
	warn = function (self, msg, section)
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="warn";msg=msg;time=os.clock()})
	end;
	error = function (self, msg, section)
		section = section or self.defaultSectionName
		self.msgs[section] = self.msgs[section] or {}
		table.insert(self.msgs[section], {level="error";msg=msg;time=os.clock()})
	end;
	__tostring = function (self)
		local res, section, msgs = "<script type=\"text/javascript\">//<![CDATA[\n"
		for section, msgs in pairs(self.msgs) do
			local _, info
			res = res.."console.group(\""..section.."\");\n"
			for _, info in ipairs(msgs) do
				if "string" == type(info.msg) then
					res = res.."console."..info.level.."(\""..info.msg.."\");\n"
				else
					res = res.."console."..info.level.."("..json.to(info.msg)..");\n"
				end
			end
			res = res.."console.groupEnd();\n"
		end
		return res.."//]]></script>"
	end;
}

return {Debugger=Debugger;Fire=Fire}
