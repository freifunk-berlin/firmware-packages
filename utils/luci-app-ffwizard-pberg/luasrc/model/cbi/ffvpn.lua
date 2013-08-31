--[[
LuCI - Lua Configuration Interface

Copyright 2013 Patrick Grimm <patrick@lunatiki.de>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id$

]]--

local fs  = require "nixio.fs"
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local has_ovpn = fs.access("/usr/sbin/openvpn")
if not has_ovpn then return end
local has_config = fs.access("/etc/config/openvpn")

if not has_antennas then
	luci.sys.exec("touch /etc/config/openvpn")
end

local m = Map("openvpn", translate("OpenVPN"))
local s = m:section( TypedSection, "openvpn", translate("OpenVPN instances"), translate("Below is a list of configured OpenVPN instances and their current state") )
s.addremove = true

s:tab("main","main")

local enabled = s:taboption("main", Flag, "enabled", translate("Enabled") )
enabled.optional=false

local active = s:taboption("main", DummyValue, "_active", translate("Started") )
function active.cfgvalue(self, section)
	local pid = fs.readfile("/var/run/openvpn-%s.pid" % section)
	if pid and #pid > 0 and tonumber(pid) ~= nil then
		return (sys.process.signal(pid, 0))
			and translatef("yes (%i)", pid)
			or  translate("no")
	end
	return translate("no")
end

local updown = s:taboption("main", Button, "_updown", translate("Start/Stop") )
updown._state = false
function updown.cbid(self, section)
	local pid = fs.readfile("/var/run/openvpn-%s.pid" % section)
	self._state = pid and #pid > 0 and sys.process.signal(pid, 0)
	self.option = self._state and "stop" or "start"
	
	return AbstractValue.cbid(self, section)
end
function updown.cfgvalue(self, section)
	self.title = self._state and "stop" or "start"
	self.inputstyle = self._state and "reset" or "reload"
end
function updown.write(self, section, value)
	if self.option == "stop" then
		luci.sys.call("/etc/init.d/openvpn down %s" % section)
	else
		luci.sys.call("/etc/init.d/openvpn up %s" % section)
	end
end

local status = s:taboption("main", DummyValue, "status", translate("Status") )
function status.cfgvalue(self, section)
	local status = fs.readfile(uci:get("openvpn",section,"status") or "")
	if status then
		local rx = status:match("TUN/TAP read bytes,%s*(%d+)") or "?"
		local tx = status:match("TUN/TAP write bytes,%s*(%d+)") or "?"
		return "rx/tx "..rx.."/"..tx
	else
		return "?"
	end
end

local cert = s:taboption("main", FileUpload, "cert", translate("Local Certificate"),"freifunk_client.crt")
cert.default="/etc/openvpn/freifunk_client.crt"
cert.optional = false

local key = s:taboption("main", FileUpload, "key", translate("Local Key"),"freifunk_client.key")
key.default="/etc/openvpn/freifunk_client.key"
key.optional = false

s:tab("adv","adv")

local server = s:taboption("adv", Value, "server", translate("Server"))
server:depends("client","")
server.rmempty = true
server.optional = true

local client = s:taboption("adv", Flag, "client", translate("Client"))
client:depends("server","")
client.default=1
client.rmempty = true
client.optional = true

local dh = s:taboption("adv", FileUpload, "dh", translate("dh pem"), "freifunk-dh2048.pem")
dh.default="/etc/openvpn/freifunk-dh2048.pem"
dh.optional = false
dh:depends("client","")

local ca = s:taboption("adv", FileUpload, "ca", translate("Certificate authority"), "freifunk-ca.crt")
ca.default="/etc/openvpn/freifunk-ca.crt"
ca.optional = false

local port = s:taboption("adv", Value, "port", translate("IPv4-Port"))
port:depends("client","")
port.rmempty = false
port.default=1194
port.optional = false

local lport = s:taboption("adv", Value, "lport", translate("Local IPv4-Port"))
lport:depends({client = "1", nobind = ""})
lport.rmempty = true
lport.default=1192
lport.optional = false

local proto = s:taboption("adv", Value, "proto", translate("IPv4-Proto"))
proto.rmempty = true
proto.default="udp"
proto.optional = false

local dev = s:taboption("adv", Value, "dev", translate("Device"))
dev.rmempty = true
dev.default="tun"
dev.optional = false

local dev = s:taboption("adv", Value, "dev_type", translate("Device Type"))
dev.rmempty = true
dev.default="tun"
dev.optional = false

local ptun = s:taboption("adv", Flag, "persist_tun", translate("Persist tun"))
ptun.rmempty = true
ptun.default=1
ptun.optional = false

local pkey = s:taboption("adv", Flag, "persist_key", translate("Persist key"))
pkey.rmempty = true
pkey.default=1
pkey.optional = false

local nobind = s:taboption("adv", Flag, "nobind", translate("No bind"))
nobind.rmempty = true
nobind.default=1
nobind.optional = false

local ctype = s:taboption("adv", Value, "ns_cert_type", translate("NS Cert type"))
ctype:depends("client","1")
ctype.rmempty = true
ctype.default=1
ctype.optional = false

local comp = s:taboption("adv", Value, "comp_lzo", translate("Compresion lzo"))
comp.rmempty = true
comp.default="no"
comp.optional = false

local cipher = s:taboption("adv", Value, "cipher", translate("Cipher"))
cipher.rmempty = true
cipher.default="none"
cipher.optional = false

local remote = s:taboption("adv", Value, "remote", translate("Remote"))
remote:depends("client","1")
remote.rmempty = true
remote.default="vpn03.berlin.freifunk.net 1194 udp"
remote.optional = false

local status = s:taboption("adv", Value, "status", translate("Status"))
function status.default(self, section)
	return "/var/log/openvpn-status-"..section..".log"
end
status.rmempty = true
status.optional = false

return m

