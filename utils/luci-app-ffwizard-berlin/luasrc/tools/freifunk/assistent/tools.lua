local uci = require "luci.model.uci".cursor()
local tools = require "luci.tools.freifunk.freifunk-berlin"

module("luci.tools.freifunk.assistent.tools", package.seeall)

-- Deletes all references of a wifi device
function wifi_delete_ifaces(device)
	local cursor = uci.cursor()
	cursor:delete_all("wireless", "wifi-iface", {device=device})
	cursor:save("wireless")
end


function statistics_interface_add(mod, interface)
	local c = uci.cursor()
	local old = c:get("luci_statistics", mod, "Interfaces")
	c:set("luci_statistics", mod, "Interfaces", (old and old .. " " or "") .. interface)
	c:save("luci_statistics")
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


-- Removes interface from zone
function firewall_zone_remove_interface(name, interface)
	local cursor = uci.cursor()
	local zone = firewall_find_zone(name)
	if zone then
		local net = cursor:get("firewall", zone, "network")
		local new = tools.remove_list_entry(net, interface)
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


-- checks if root-password has been set via CGI has_root-pass 
function hasRootPass()
	local jsonc = require "luci.jsonc"
	local isPasswordSet = true

	local f = io.popen("wget http://localhost/ubus -q -O - --post-data '{ \"jsonrpc\": \"2.0\", \"method\": \"call\", \"params\": [ \"00000000000000000000000000000000\", \"ffwizard-berlin\", \"has_root-pass\", {} ] }'")
	local ret = f:read("*a")
	f:close()

	local content = jsonc.parse(ret)
	local result = content.result
	local test = result[2]
	logger ("checking for root-password ..." .. test.password_is_set)

	if test.password_is_set == "no" then
		isPasswordSet = false
	end
	return isPasswordSet
end


-- Helpers --

function logger(msg)
        tools.logger(msg, "ffwizard", 5)
end
