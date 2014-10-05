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
  if sharenet == "1" then
    -- values have to be in kilobits/seconed
    local up = 128
    local down = 1024
    if uci:get("ffwizard", "settings", "customBW") == "0" then
      local usersBandwidthUp = bandwidths[uci:get("ffwizard", "settings", "usersBandwidth")].up
      local usersBandwidthDown = bandwidths[uci:get("ffwizard", "settings", "usersBandwidth")].down
      local shareBandwidth = uci:get("ffizward", "settings", "usersBandwidth") or 100
      up = (usersBandwidthUp * 100 / shareBandwidth) * 1000
      down = (usersBandwidthDown * 100 / shareBandwidth) * 1000
    elseif uci:get("ffwizard", "settings", "customBW") == "1" then
      up = uci:get("ffwizard", "settings", "usersBandwidthUp") * 1000
      down = uci:get("ffwizard", "settings", "usersBandwidthDown") * 1000
    end
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
