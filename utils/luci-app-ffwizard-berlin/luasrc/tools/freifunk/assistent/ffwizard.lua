--[[
LuCI - Lua Configuration Interface

Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

$Id$

]]--

local uci = require "luci.model.uci"
local util = require "luci.util"
local table = require "table"
local sys = require "luci.sys"
local type = type

module "luci.tools.freifunk.assistent.ffwizard"

function configureWatchdog()
	if (sharenet =="1") then
		uci:section("freifunk-watchdog", "process", nil, {
			process="openvpn",
			initscript="/etc/init.d/openvpn"
		})
	end
	uci:save("freifunk-watchdog")
end


function configureQOS()
	if (sharenet == "1") then
		uci:delete("qos","wan")
		uci:delete("qos","lan")
		uci:section("qos", 'interface', "wan", {
		enabled = "1",
			classgroup = "Default",
		})
	end
	uci:save("qos")
end
