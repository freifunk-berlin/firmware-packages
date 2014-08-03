local util = require "luci.util"
local uci = require "luci.model.uci".cursor()


local sharenet = uci:get("freifunk","wizard","sharenet")
--TODO set profile in general config and read here                                                                       
local community = "berlin"                                                                                               
local external = "profile_"..community

module "luci.tools.freifunk.assistent.olsr"

function prepareOLSR(community)
	local c = uci.cursor()
	uci:delete_all("olsrd", "olsrd")
	uci:delete_all("olsrd", "InterfaceDefaults")
	uci:delete_all("olsrd", "Interface")
	uci:delete_all("olsrd", "Hna4")
	uci:delete_all("olsrd", "Hna6")
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_mdns.so.1.0.0"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_p2pd.so.0.1.0"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_httpinfo.so.0.1"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_jsoninfo.so.0.0"})

	local olsrifbase = uci:get_all("freifunk", "olsr_interface") or {}
	util.update(olsrifbase, uci:get_all(community, "olsr_interface") or {})
	uci:section("olsrd", "InterfaceDefaults", nil, olsrifbase)

	uci:delete_all("olsrd6", "olsrd")
	uci:delete_all("olsrd6", "InterfaceDefaults")
	uci:delete_all("olsrd6", "Interface")
	uci:delete_all("olsrd6", "Hna4")
	uci:delete_all("olsrd6", "Hna6")
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_mdns.so.1.0.0"})
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_p2pd.so.0.1.0"})
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_httpinfo.so.0.1"})
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_jsoninfo.so.0.0"})

	uci:section("olsrd6", "InterfaceDefaults", nil, olsrifbase)

	-- Write p2pd settings here because its needed in model/cbi/freifunk/assistent/wireless.lua
	uci:section("olsrd", "LoadPlugin", nil, {
		library = "olsrd_p2pd.so.0.1.0",
		P2pdTtl = "10",
		UdpDestPort = "224.0.0.2515353",
		ignore = "1",
	})
	uci:section("olsrd6", "LoadPlugin", nil, {
                library = "olsrd_p2pd.so.0.1.0",
                P2pdTtl = "10",
                UdpDestPort = "ff02::fb 5353",
                ignore = "1",
        })

	uci:save("olsrd")
	uci:save("olsrd6")
end

function configureOLSR()
	local olsrbase = uci:get_all("freifunk", "olsrd") or {}                           
	util.update(olsrbase, uci:get_all(external, "olsrd") or {})                      
	olsrbase.IpVersion='4'                                                          
	if (sharenet) then
        	olsrbase.SmartGateway="yes"
        	olsrbase.SmartGatewaySpeed="500 10000"
        	olsrbase.RtTable="111"
       	 	olsrbase.RtTableDefault="112"
        	olsrbase.RtTableTunnel="113"
	end
	uci:section("olsrd", "olsrd", nil, olsrbase)                                      

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

	uci:section("olsrd", "LoadPlugin", nil, {
		accept = "0.0.0.0",
		library = "olsrd_jsoninfo.so.0.0",
		ignore = "0"
	})
	uci:section("olsrd6", "LoadPlugin", nil, {
		accept = "::",
		library = "olsrd_jsoninfo.so.0.0",
		ignore = "0",
		port = '9091'
	})

	if (sharenet) then
		uci:section("olsrd", "LoadPlugin", nil, {library="olsrd_dyn_gw_plain.so.0.4"})
		uci:section("olsrd6", "LoadPlugin", nil, {library="olsrd_dyn_gw_plain.so.0.4"})
	else
		-- Disable gateway_plain plugin
		uci:section("olsrd", "LoadPlugin", nil, {
        		library = "olsrd_dyn_gw_plain.so.0.4", 
        		ignore = 1,
		})
		uci:section("olsrd6", "LoadPlugin", nil, {
			library = "olsrd_dyn_gw_plain.so.0.4",
			ignore = 1,
		})
	end

	-- Delete old watchdog settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_watchdog.so.0.1"})
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_watchdog.so.0.1"})
	-- Write new watchdog settings
	uci:section("olsrd", "LoadPlugin", nil, {
        	library = "olsrd_watchdog.so.0.1",
        	file = "/var/run/olsrd.watchdog",
        	interval = "30"
	})
	uci:section("olsrd6", "LoadPlugin", nil, {
		library = "olsrd_watchdog.so.0.1",
		file = "/var/run/olsrd.watchdog",
		interval = "30"
	})
        
	-- Delete old nameservice settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_nameservice.so.0.3"})
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_nameservice.so.0.3"})
	-- Write new nameservice settings
	local suffix = uci:get_first(external, "community", "suffix") or "olsr"
	uci:section("olsrd", "LoadPlugin", nil, {
	        library = "olsrd_nameservice.so.0.3",
        	suffix = "." .. suffix ,
	        hosts_file = "/tmp/hosts/olsr",
        	latlon_file = "/var/run/latlon.js",
	        services_file = "/var/etc/services.olsr"
	})
	uci:section("olsrd6", "LoadPlugin", nil, {
	        library = "olsrd_nameservice.so.0.3",
		suffix = "." .. suffix ,
	        hosts_file = "/tmp/hosts/olsr",
		latlon_file = "/var/run/latlon.js.ipv6",
	        services_file = "/var/etc/services.olsr.ipv6"
	})
	uci:save("olsrd")
	uci:save("olsrd6")

end
