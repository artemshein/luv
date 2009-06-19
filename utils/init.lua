local table = require "luv.table"
local Object = require"luv.oop".Object
local require, type, getfenv, pairs = require, type, getfenv, pairs
local debug = debug

module(...)

local Version = Object:extend{
	__tag = .....".Version",
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
	end,
	__tostring = function (self) return self:full() end
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
	init = function (self, children, connector)
		self.connector = connector
		self.children = children
	end;
	add = function (self, child, connector)
		if table.size(self.children) < 2 then
			connector = self.connector
		end
		if connector == self.connector then
			table.insert(self.children, child)
		else
			local obj = self:clone()
			self.connector = connector
			self.children = {obj;child}
		end
	end;
	getConnector = function (self) return self.connector end;
	getChildren = function (self) return self.children end;
}

local function lazyRequire (module)
	local res = {__module = module}
	local mt = getmetatable(res) or {}
	mt.__index = function (self, key)
		local module = require(self.__module)
		self.__module = nil
		for k, v in pairs(module) do
			self[k] = v
		end
		setmetatable(self, getmetatable(module))
		return self[key]
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
