local util = require "luci.util"
local uci = require "luci.model.uci".cursor()


local sharenet = uci:get("freifunk","wizard","sharenet")
--TODO set profile in general config and read here                                                                       
local community = "berlin"                                                                                               
local external = "profile_"..community

module "luci.tools.freifunk.assistent.olsr"

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
	local olsrifbase = uci:get_all("freifunk", "olsr_interface") or {}                
	util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})           
	uci:section("olsrd", "InterfaceDefaults", nil, olsrifbase)
	uci:save("olrsd")
end

function configureOLSRPlugins()
	uci:foreach("olsrd", "LoadPlugin",                                                                               
        	function(s)
                	if s.library == "olsrd_jsoninfo.so.0.0" then 
               	 	uci:set("olsrd", s['.name'], "accept", "0.0.0.0")
        	end
	end) 

	-- Write olsrdv4 new p2pd settings 
	uci:section("olsrd", "LoadPlugin", nil, {
        	library = "olsrd_p2pd.so.0.1.0", 
        	P2pdTtl = 10,
        	UdpDestPort="224.0.0.2515353",
        	ignore = 1,
	})
	if (sharenet) then
		uci:section("olsrd", "LoadPlugin", nil, {library="olsrd_dyn_gw_plain.so.0.4"})
	else
		-- Disable gateway_plain plugin
		uci:section("olsrd", "LoadPlugin", nil, {
        		library = "olsrd_dyn_gw_plain.so.0.4", 
        		ignore = 1,
		})
	end

	-- Delete old watchdog settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_watchdog.so.0.1"})
	-- Write new watchdog settings
	uci:section("olsrd", "LoadPlugin", nil, {
        	library = "olsrd_watchdog.so.0.1",
        	file = "/var/run/olsrd.watchdog",
        	interval = "30"
	})
        
	-- Delete old nameservice settings
	uci:delete_all("olsrd", "LoadPlugin", {library="olsrd_nameservice.so.0.3"})
	-- Write new nameservice settings
	local suffix = uci:get_first(external, "community", "suffix") or "olsr"
	uci:section("olsrd", "LoadPlugin", nil, {
	        library = "olsrd_nameservice.so.0.3",
        	suffix = "." .. suffix ,
	        hosts_file = "/tmp/hosts/olsr",
        	latlon_file = "/var/run/latlon.js",
	        services_file = "/var/etc/services.olsr"
	})
	uci:save("olsrd")

end
