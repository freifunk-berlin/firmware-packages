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

local uci = require "luci.model.uci".cursor()
local bandwidths = require "luci.tools.freifunk.assistent.defaults".bandwidths()
local tools = require "luci.tools.freifunk.assistent.tools"
local table = require "table"
local type = type
local sharenet = uci:get("ffwizard", "settings", "sharenet")

module ("luci.tools.freifunk.assistent.ffwizard", package.seeall)

function configureWatchdog()
	if (sharenet =="1") then
		uci:section("freifunk-watchdog", "process", nil, {
			process="openvpn",
			initscript="/etc/init.d/openvpn"
		})
		uci:save("freifunk-watchdog")
	end
end


function configureQOS()
  local usersBandwidthUp = bandwidths[uci:get("ffwizard", "settings", "usersBandwidth")].up
  local usersBandwidthDown = bandwidths[uci:get("ffwizard", "settings", "usersBandwidth")].down
  local shareBandwidth = uci:get("ffizward", "settings", "usersBandwidth") or 100
  local up = (usersBandwidthUp * 100 / shareBandwidth) * 1000
  local down = (usersBandwidthDown * 100 / shareBandwidth) * 1000
  if (sharenet == "1") then
    uci:delete("qos","wan")
    uci:delete("qos","lan")
    uci:section("qos", 'interface', "wan", {
      enabled = "1",
      classgroup = "Default",
      upload = up,
      download = down
    })
    local s = uci:get_first("olsrd", "olsrd")
    uci:set("olsrd", s, "SmartGatewaySpeed", up.." "..down)
    uci:set("olsrd", s, "SmartGatewayUplink", "both")
    uci:save("olsrd")
    uci:save("qos")
  end
end
