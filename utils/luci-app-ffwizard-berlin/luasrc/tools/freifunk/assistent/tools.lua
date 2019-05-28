local sys = require "luci.sys"
local util = require "luci.util"
local uci = require "luci.model.uci".cursor()

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


-- checks if root-password has been set via CGI has_root-pass 
function hasRootPass()
	logger ("checking for root-password ...")

	local isPasswordSet = true
	local f = io.popen("wget http://localhost/ubus -q -O - --post-data '{ \"jsonrpc\": \"2.0\", \"method\": \"call\", \"params\": [ \"00000000000000000000000000000000\", \"ffwizard-berlin\", \"has_root-pass\", {} ] }'")
	local ret = f:read("*a")
	f:close()
	logger(ret)
	local jsonc = require "luci.jsonc"
	
	local content = jsonc.parse(ret)

	print(content.jsonrpc) -- should be 2.0
	print(content.tosting(id)) -- is nil, as per requests id?
	local result = content.result
 	for i,line in ipairs(result) do
	      print(tostring(line))
    	end
	print("debug2")
	
	local test = result[2]
	print(test.password_is_set)

	if test.password_is_set == "no" then
		isPasswordSet = false
	end
	return isPasswordSet
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


function logger(msg)
        sys.exec("logger -t ffwizard -p 5 '"..msg.."'")
end

--Merge the options of multiple config files into a table.
--
--configs: an array of strings, each representing a config file.  
--  The order is important since  the first config file is read, 
--  then the following.  Any options in the following config files
--  overwrite the values of any previous config files. 
--  e.g. {"freifunk", "profile_berlin"}
--sectionType: the section type to merge. e.g. "defaults"
--sectionName: the section to merge. e.g. "olsrd"
function getMergedConfig(configs, sectionType, sectionName)
	local data = {}
	for i, config in ipairs(configs) do
		uci:foreach(config, sectionType,
			function(s)
				if s['.name'] == sectionName then
					for key, val in pairs(s) do
						if string.sub(key, 1, 1) ~= '.' then
							data[key] = val
						end
					end
				end
			end)
		end
	return data
end

function mergeInto(config, section, options)
	local s = uci:get_first(config, section)
	if (section) then
		uci:tset(config, s, options)
	else
		uci:section(config, section, nil, options)
	end
	uci:save(config)
end
