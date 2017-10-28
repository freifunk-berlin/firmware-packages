local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local tools = require "luci.tools.freifunk.assistent.tools"

local sharenet = uci:get("ffwizard","settings","sharenet")
local community = "profile_"..uci:get("freifunk", "community", "name")

module "luci.tools.freifunk.assistent.olsr"

function prepareOLSR()
	local c = uci.cursor()
	uci:delete_all("olsrd", "Interface")
	uci:delete_all("olsrd", "Hna4")

	uci:delete_all("olsrd6", "Interface")
	uci:delete_all("olsrd6", "Hna6")

	uci:save("olsrd")
	uci:save("olsrd6")
end


function configureOLSR()
	-- olsr 4
	local olsrbase = uci:get_all("freifunk", "olsrd") or {}
	util.update(olsrbase, uci:get_all(community, "olsrd") or {})
	uci:tset("olsrd", "olsrd", olsrbase)

	-- olsr 6
	local olsr6base = uci:get_all("freifunk", "olsrd6") or {}
	util.update(olsr6base, uci:get_all(community, "olsrd6") or {})
	uci:tset("olsrd6", "olsrd", olsr6base)

	-- set HNA for olsr6
	local ula_prefix = uci:get("network","globals","ula_prefix")
	if ula_prefix then
		ula_prefix = ip.IPv6(ula_prefix)
		if ula_prefix:is6() then
			uci:section("olsrd6", "Hna6", nil, {
				prefix = ula_prefix:prefix(),
				netaddr = ula_prefix:network():string()
			})
		end
	end

  -- olsr 4 interface defaults
  local olsrifbase = uci:get_all("freifunk", "olsr_interface") or {}
  util.update(olsrifbase, uci:get_all(community, "olsr_interface") or {})
  local s = uci:get_first("olsrd", "InterfaceDefaults")
  if (s) then
    uci:tset("olsrd", s, olsrifbase)
  else
    uci:section("olsrd", "InterfaceDefaults", nil, olsrifbase)
  end

  uci:save("olsrd")
	uci:save("olsrd6")
end


function configureOLSRPlugins()
	local suffix = uci:get_first(community, "community", "suffix") or "olsr"
	updatePlugin("olsrd_nameservice.so.0.3", "suffix", "."..suffix)
	updatePluginInConfig("olsrd", "olsrd_dyn_gw.so.0.5", "PingCmd", "ping -c 1 -q -I ffuplink %s")
	updatePluginInConfig("olsrd", "olsrd_dyn_gw.so.0.5", "PingInterval", "30")
	uci:save("olsrd")
	uci:save("olsrd6")
end


function updatePluginInConfig(config, pluginName, key, value)
	uci:foreach(config, "LoadPlugin",
		function(plugin)
			if (plugin.library == pluginName) then
				uci:set(config, plugin['.name'], key, value)
			end
		end)
end


function updatePlugin(pluginName, key, value)
	updatePluginInConfig("olsrd", pluginName, key, value)
	updatePluginInConfig("olsrd6", pluginName, key, value)
end
