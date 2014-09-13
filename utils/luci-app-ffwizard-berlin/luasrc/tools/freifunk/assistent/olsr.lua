local util = require "luci.util"
local uci = require "luci.model.uci".cursor()
local tools = require "luci.tools.freifunk.assistent.ffwizard"

local sharenet = uci:get("ffwizard","settings","sharenet")
local community = "profile_"..uci:get("freifunk", "community", "name")

module "luci.tools.freifunk.assistent.olsr"

function prepareOLSR()
	local c = uci.cursor()
	uci:delete_all("olsrd", "olsrd")
	uci:delete_all("olsrd", "InterfaceDefaults")
	uci:delete_all("olsrd", "Interface")
	uci:delete_all("olsrd", "Hna4")
	uci:delete_all("olsrd", "Hna6")
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})

	uci:delete_all("olsrd6", "olsrd")
	uci:delete_all("olsrd6", "InterfaceDefaults")
	uci:delete_all("olsrd6", "Interface")
	uci:delete_all("olsrd6", "Hna4")
	uci:delete_all("olsrd6", "Hna6")
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})

	uci:save("olsrd")
	uci:save("olsrd6")
end

function configureOLSR()
	local olsrbase = uci:get_all("freifunk", "olsrd") or {}
	util.update(olsrbase, uci:get_all(community, "olsrd") or {})
	olsrbase.IpVersion='4'
	if (sharenet == "1") then
        	olsrbase.SmartGateway="yes"
        	olsrbase.SmartGatewaySpeed="500 10000"
        	olsrbase.RtTable="111"
       	 	olsrbase.RtTableDefault="112"
        	olsrbase.RtTableTunnel="113"
	end
	uci:section("olsrd", "olsrd", nil, olsrbase)

	local olsrifbase = uci:get_all("freifunk", "olsr_interface") or {}
	util.update(olsrifbase, uci:get_all(community, "olsr_interface") or {})
	uci:section("olsrd", "InterfaceDefaults", nil, olsrifbase)
	uci:section("olsrd6", "InterfaceDefaults", nil, olsrifbase)

	--just guessing here :/
	uci:section("olsrd6", "olsrd", nil, {
                AllowNoInt = "yes",
                LinkQualityAlgorithm = "etx_ffeth",
                FIBMetric = "flat",
                TcRedundancy = "2",
                Pollrate = "0.025"
        })

	uci:save("olsrd")
	uci:save("olsrd6")
end

function configureOLSRPlugins()
	local suffix = uci:get_first(community, "community", "suffix") or "olsr"
	updatePlugin("olsrd_nameservice.so.0.3", "suffix", "."..suffix)
	uci:save("olsrd")
	uci:save("olsrd6")

end

function updatePluginInConfig(config, pluginName, key, value)
	uci:foreach(config, "LoadPlugin",
		function(plugin)
			if (plugin.library == pluginName) then
				uci:set("olsrd", plugin['.name'], key, value)
			end
		end)
end

function updatePlugin(pluginName, key, value)
	updatePluginInConfig("olsrd", pluginName, key, value)
	updatePluginInConfig("olsrd6", pluginName, key, value)
end
