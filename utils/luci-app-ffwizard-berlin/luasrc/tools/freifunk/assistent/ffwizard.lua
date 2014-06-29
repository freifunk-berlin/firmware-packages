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

-- Deletes all references of a wifi device
function wifi_delete_ifaces(device)
	local cursor = uci.cursor()
	cursor:delete_all("wireless", "wifi-iface", {device=device})
	cursor:save("wireless")
end

-- Deletes a network interface and all occurences of it in firewall zones and dhcp
function network_remove_interface(iface)
	local cursor = uci.cursor()

	if not cursor:delete("network", iface) then
		return false
	end

	local aliases = {iface}
	cursor:foreach("network", "alias",
		function(section)
			if section.interface == iface then
				table.insert(aliases, section[".name"])
			end
		end)

	-- Delete Aliases and Routes
	cursor:delete_all("network", "route", {interface=iface})
	cursor:delete_all("network", "alias", {interface=iface})

	-- Delete DHCP sections
	cursor:delete_all("dhcp", "dhcp",
		 function(section)
		 	return util.contains(aliases, section.interface)
		 end)

	-- Remove OLSR sections
	cursor:delete_all("olsrd", "Interface", {Interface=iface})
	cursor:delete_all("olsrd6", "Interface", {Interface=iface})

	-- Remove Splash sections
	cursor:delete_all("luci-splash", "iface", {network=iface})

	cursor:save("network")
	cursor:save("olsrd")
	cursor:save("olsrd6")
	cursor:save("dhcp")
	cursor:save("luci-splash")
end

-- Creates a firewall zone
function firewall_create_zone(zone, input, output, forward, masq)
	local cursor = uci.cursor()
	if not firewall_find_zone(zone) then
		logger("before create firewallzone")
		local stat = cursor:section("firewall", "zone", "zone_"..zone, {
			input = input,
			output = output,
			forward = forward,
			masq = masq and "1",
			name = zone
		})
		cursor:save("firewall")
		return stat
	else
		--logger("zone "..zone.." alread exists")
	end
end

-- Adds interface to zone, creates zone on-demand
function firewall_zone_add_interface(name, interface)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	local net = cursor:get("firewall", zone, "network")
	local old = net or (cursor:get("network", name) and name)
	cursor:set("firewall", zone, "network", (old and old .. " " or "") .. interface)
	cursor:save("firewall")
end

-- Adds masq src net to zone
function firewall_zone_add_masq_src(name, src)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	local old = cursor:get("firewall", zone, "masq_src") or {}
	table.insert(old,src)
	cursor:set_list("firewall", zone, "masq_src", old)
	cursor:save("firewall")
end

-- Adds masq to zone
function firewall_zone_enable_masq(name)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	cursor:set("firewall", zone, "masq", "1")
	cursor:save("firewall")
end

-- Removes interface from zone
function firewall_zone_remove_interface(name, interface)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	if zone then
		local net = cursor:get("firewall", zone, "network")
		local new = remove_list_entry(net, interface)
		if new then
			if #new > 0 then
				cursor:set("firewall", zone, "network", new)
			else
				cursor:delete("firewall", zone, "network")
			end
			cursor:save("firewall")
		end
	end
end


-- Finds the firewall zone with given name
function firewall_find_zone(name)
	local find

	uci.cursor():foreach("firewall", "zone",
		function (section)
			if section.name == name then
				find = section[".name"]
			end
		end)

	return find
end



-- Helpers --

-- Removes a listentry, handles real and pseduo lists transparently
function remove_list_entry(value, entry)
	if type(value) == "nil" then
		return nil
	end

	local result = type(value) == "table" and value or util.split(value, " ")
	local key = util.contains(result, entry)

	while key do
		table.remove(result, key)
		key = util.contains(result, entry)
	end

	result = type(value) == "table" and result or table.concat(result, " ")
	return result ~= value and result
end

function prepareOLSR(community)
	local c = uci.cursor()
 	c:delete_all("olsrd", "olsrd") 
	c:delete_all("olsrd", "InterfaceDefaults")
	c:delete_all("olsrd", "Interface")                                     
	c:delete_all("olsrd", "Hna4")                                          
	c:delete_all("olsrd", "Hna6")
	c:delete_all("olsrd", "LoadPlugin", {library="olsrd_mdns.so.1.0.0"})                      
	c:delete_all("olsrd", "LoadPlugin", {library="olsrd_p2pd.so.0.1.0"})
	c:delete_all("olsrd", "LoadPlugin", {library="olsrd_httpinfo.so.0.1"}) 
	c:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw.so.0.5"})                                   
        c:delete_all("olsrd", "LoadPlugin", {library="olsrd_dyn_gw_plain.so.0.4"})

	
	local olsrifbase = c:get_all("freifunk", "olsr_interface") or {}                                               
        util.update(olsrifbase, c:get_all(community, "olsr_interface") or {})                                           
        c:section("olsrd", "InterfaceDefaults", nil, olsrifbase)	

	c:save("olsrd")
end

function prepareFirewall(community)
	local c = uci.cursor()
	c:delete_all("firewall","zone", {name="freifunk"})
	c:delete_all("firewall","forwarding", {dest="freifunk"})
	c:delete_all("firewall","forwarding", {src="freifunk"})
	c:delete_all("firewall","rule", {dest="freifunk"})
	c:delete_all("firewall","rule", {src="freifunk"})
	c:save("firewall")	

	local newzone = firewall_create_zone("freifunk", "ACCEPT", "ACCEPT", "REJECT", 1)
        if newzone then                                                                        
		firewall_zone_add_masq_src("freifunk", "255.255.255.255/32") 
		c:foreach("freifunk", "fw_forwarding", function(section) 
			c:section("firewall", "forwarding", nil, section)
		end) 
		c:foreach(community, "fw_forwarding", function(section)
			c:section("firewall", "forwarding", nil, section) 
		end) 
	
		c:foreach("freifunk", "fw_rule", function(section) 
			c:section("firewall", "rule", nil, section)
		end) 
		c:foreach(community, "fw_rule", function(section) 
			c:section("firewall", "rule", nil, section)
		end) 
	end
	
	c:save("firewall")
end

function logger(msg)                                                                                        
        sys.exec("logger -t ffwizard -p 5 '"..msg.."'")                                                     
end 
