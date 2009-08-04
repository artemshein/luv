local table = require "luv.table"
local require, type, getfenv, pairs = require, type, getfenv, pairs
local getmetatable, setmetatable, require = getmetatable, setmetatable, require
local Object = require "luv.oop".Object

module(...)
local property = Object.property

local Version = Object:extend{
	__tag = .....".Version";
	_state = "stable";
	major = property"number";
	minor = property"number";
	patch = property"number";
	state = property"string";
	rev = property"number";
	codename = property"string";
	init = function (self, major, minor, patch, state, rev, codename)
		self:major(major)
		self:minor(minor or 0)
		self:patch(patch or 0)
		self:state(state or "stable")
		if rev then self:rev(rev) end
		if codename then self:codename(codename) end
	end;
	full = function (self)
		local res = self:major().."."..self:minor()
		if 0 ~= self:patch() then
			res = res.."."..self:patch()
		end
		if "stable" ~= self:state() then
			res = res..self:state()
		end
		if self:rev() then
			res = res.." rev"..self:rev()
		end
		if self:codename() then
			res = res.." "..self:codename()
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
	connector = property;
	children = property;
	init = function (self, children, connector)
		self:connector(connector)
		self:children(children)
	end;
	add = function (self, child, connector)
		if table.size(self:children()) < 2 then
			 self:connector(connector)
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
