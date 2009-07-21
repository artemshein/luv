local table = require "luv.table"
local require, type, getfenv, pairs = require, type, getfenv, pairs
local getmetatable, setmetatable, require = getmetatable, setmetatable, require
local Object = require "luv.oop".Object

module(...)

local Version = Object:extend{
	__tag = .....".Version";
	_state = "stable";
	init = function (self, major, minor, patch, state, rev, codename)
		self._major = major
		self._minor = minor or 0
		self._patch = patch or 0
		self._state = state or "stable"
		self._rev = rev
		self._codename = codename
	end;
	full = function (self)
		local res = self._major.."."..self._minor
		if 0 ~= self._patch then
			res = res.."."..self._patch
		end
		if "stable" ~= self._state then
			res = res..self._state
		end
		if self._rev then
			res = res.." rev"..self._rev
		end
		if self._codename then
			res = res.." "..self._codename
		end
		return res
	end;
	__tostring = function (self) return self:full() end;
}

local sendEmail = function (from, to, subject, body, server)
	local smtp, mime = require "socket.smtp", require "mime"
	return smtp.send{
		from = from;
		rcpt = to;
		source = smtp.message{
			headers = {
				from = from;
				to = to;
				subject = "=?utf-8?b?"..(mime.b64(subject)).."?=";
			};
			body = {{
				headers = {
					["content-type"] = 'text/plain; charset="utf-8"';
					["content-transfer-encoding"] = "BASE64";
				};
				body = (mime.b64(body));
			}};
		};
		server = server;
	}
end

local TreeNode = Object:extend{
	__tag = .....".TreeNode";
	connector = Object.property;
	children = Object.property;
	init = function (self, children, connector)
		self:connector(connector)
		self:children(children)
	end;
	add = function (self, child, connector)
		if table.size(self:children()) < 2 then
			connector = self:connector()
		end
		if connector == self:connector() then
			table.insert(self:children(), child)
		else
			local obj = self:clone()
			self:connector(connector)
			self:children{obj;child}
		end
		return self
	end;
}

local function lazyRequire (module)
	local res = {__module = module}
	local mt = getmetatable(res) or {}
	mt.__index = function (self, key)
		local module = require(self.__module)
		self.__module = nil
		setmetatable(self, {__index=module;__newindex=module})
		return module[key]
	end
	setmetatable(res, mt)
	return res
end

return {
	Version=Version;
	sendEmail=sendEmail;
	TreeNode=TreeNode;
	lazyRequire=lazyRequire;
}
