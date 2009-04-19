local Object = require"luv.oop".Object
local require = require
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
	local smtp = require "socket.smtp"
	local mime = require "mime"
	local ltn12 = require "ltn12"
	-- Mime.encode BASE64 have a bug, so no UTF8 for now =(
	--local subject64 = subject --mime.encode"base64"(subject)
	--[[local body64 = ltn12.source.chain(
		ltn12.source.string(body),
		ltn12.filter.chain(
			mime.encode("base64"),
			mime.wrap()
		)
	)()]]

	return smtp.send{
		from = from;
		rcpt = to;
		source = smtp.message{
			headers = {
				from = from;
				to = to;
				subject = subject; --"=?utf8?b?"..subject64.."?=";
			};
			body = body;
			--[[
			body = {{
				headers = {
					["content-type"] = 'text/plain; charset="latin1"';
					--["content-transfer-encoding"] = "BASE64";
				};
				body = body;
			}};]]
		};
		server = server;
	}
end

return {
	Version = Version;
	sendEmail=sendEmail;
}
