

	-- Create wireless ip4/ip6 and firewall config
	uci:foreach("wireless", "wifi-device",
	function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
		node_ip6 = luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device) and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device))
		if not node_ip or not network or not network:contains(node_ip) then
			meship.tag_missing[section] = true
			node_ip = nil
			return
		end
		-- rename the wireless interface s/wifi/wireless/
		local nif
		if string.find(device, "wifi") then
			nif = string.gsub(device,"wifi", netname)
		elseif string.find(device, "wl") then
			nif = string.gsub(device,"wl", netname)
		elseif string.find(device, "wlan") then
			nif = string.gsub(device,"wlan", netname)
		elseif string.find(device, "radio") then
			nif = string.gsub(device,"radio", netname)
		end

		-- Cleanup
		tools.wifi_delete_ifaces(device)
		-- tools.network_remove_interface(device)
		uci:delete("network", device .. "dhcp")
		uci:delete("network", device)
		tools.firewall_zone_remove_interface("freifunk", device)
		-- tools.network_remove_interface(nif)
		uci:delete("network", nif .. "dhcp")
		uci:delete("network", nif)
		tools.firewall_zone_remove_interface("freifunk", nif)
		-- Delete old dhcp
		uci:delete("dhcp", device)
		uci:delete("dhcp", device .. "dhcp")
		uci:delete("dhcp", nif)
		uci:delete("dhcp", nif .. "dhcp")
		-- Delete old splash
		uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
		uci:delete_all("luci_splash", "iface", {network=nif.."dhcp", zone="freifunk"})
		-- Delete old radvd
		if has_radvd then
			uci:delete_all("radvd", "interface", {interface=nif.."dhcp"})
			uci:delete_all("radvd", "interface", {interface=nif})
			uci:delete_all("radvd", "prefix", {interface=nif.."dhcp"})
			uci:delete_all("radvd", "prefix", {interface=nif})
		end

		-- New Config
		-- Tune wifi device
		local ssiduci = uci:get("freifunk", community, "ssid")
		local ssiddot = string.find(ssiduci,'%..*')
		local ssidshort
		if ssiddot then
			ssidshort = string.sub(ssiduci,ssiddot)
		else
			ssidshort = ssiduci
		end

		local devconfig = uci:get_all("freifunk", "wifi_device")
		util.update(devconfig, uci:get_all(external, "wifi_device") or {})
		local ssid = uci:get("freifunk", community, "ssid")
		local channel = luci.http.formvalue("cbid.ffwizward.1.chan_" .. device)
		local hwmode = "11bg"
		local bssid = "02:CA:FF:EE:BA:BE"
		local mrate = 5500
		if channel and channel ~= "default" then
			if devconfig.channel ~= channel then
				devconfig.channel = channel
				local chan = tonumber(channel)
				if chan >= 0 and chan < 10 then
					bssid = channel .. "2:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan == 10 then
					bssid = "02:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 11 and chan <= 14 then
					bssid = string.format("%X",channel) .. "2:CA:FF:EE:BA:BE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 36 and chan <= 64 then
					hwmode = "11a"
					mrate = ""
					outdoor = 0
					bssid = "00:" .. channel ..":CA:FF:EE:EE"
					ssid = "ch" .. channel .. ssidshort
				elseif chan >= 100 and chan <= 140 then
					hwmode = "11a"
					mrate = ""
					outdoor = 1
					bssid = "01:" .. string.sub(channel, 2) .. ":CA:FF:EE:EE"
					ssid = "ch" .. channel .. ssidshort
				end
				devconfig.hwmode = hwmode
				devconfig.outdoor = outdoor
			end
		end
		uci:tset("wireless", device, devconfig)
		-- Create wifi iface
		local ifconfig = uci:get_all("freifunk", "wifi_iface")
		util.update(ifconfig, uci:get_all(external, "wifi_iface") or {})
		ifconfig.device = device
		ifconfig.network = nif
		if ssid then
			-- See Table https://kifuse02.pberg.freifunk.net/moin/channel-bssid-essid 
			ifconfig.ssid = ssid
		else
			ifconfig.ssid = "olsr.freifunk.net"
		end
		-- See Table https://kifuse02.pberg.freifunk.net/moin/channel-bssid-essid	
		ifconfig.bssid = bssid
		ifconfig.encryption="none"
		-- Read Preset 
		local netconfig = uci:get_all("freifunk", "interface")
		util.update(netconfig, uci:get_all(external, "interface") or {})
		netconfig.proto = "static"
		netconfig.ipaddr = node_ip:string()
		netconfig.ip6addr = node_ip6:string()
		uci:section("network", "interface", nif, netconfig)
		if has_radvd then
			uci:section("radvd", "interface", nil, {
				interface          =nif,
				AdvSendAdvert      =1,
				AdvManagedFlag     =0,
				AdvOtherConfigFlag =0,
				ignore             =0
			})
			uci:section("radvd", "prefix", nil, {
				interface          =nif,
				AdvOnLink          =1,
				AdvAutonomous      =1,
				AdvRouterAddr      =0,
				ignore             =0,
			})
			uci:save("radvd")
		end
		local new_hostname = node_ip:string():gsub("%.", "-")
		uci:set("freifunk", "wizard", "hostname", new_hostname)
		uci:save("freifunk")
		tools.firewall_zone_add_interface("freifunk", nif)
		uci:save("firewall")
		-- Collect MESH DHCP IP NET
		local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
		if client then
			local dhcpmeshnet = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
			local ifacelist = uci:get_list("manager", "heartbeat", "interface") or {}
			table.insert(ifacelist,nif .. "dhcp")
			uci:set_list("manager", "heartbeat", "interface", ifacelist)
			uci:save("manager")
			if dhcpmeshnet then
				if not dhcpmeshnet:minhost() or not dhcpmeshnet:mask() then
					dhcpmesh.tag_missing[section] = true
					dhcpmeshnet = nil
					return
				end
				dhcp_ip = dhcpmeshnet:minhost():string()
				dhcp_mask = dhcpmeshnet:mask():string()
			else
				local subnet_prefix = tonumber(uci:get("freifunk", community, "splash_prefix")) or 27
				local pool_network = uci:get("freifunk", community, "splash_network") or "10.104.0.0/16"
				local pool = luci.ip.IPv4(pool_network)
				local ip = tostring(node_ip)
				if pool and ip then
					local hosts_per_subnet = 2^(32 - subnet_prefix)
					local number_of_subnets = (2^pool:prefix())/hosts_per_subnet
					local seed1, seed2 = ip:match("(%d+)%.(%d+)$")
					if seed1 and seed2 then
						math.randomseed(seed1 * seed2)
					end
					local subnet = pool:add(hosts_per_subnet * math.random(number_of_subnets))
					dhcp_ip = subnet:network(subnet_prefix):add(1):string()
					dhcp_mask = subnet:mask(subnet_prefix):string()
				end
			end
			if dhcp_ip and dhcp_mask then
				-- Create alias
				local aliasbase = uci:get_all("freifunk", "alias")
				util.update(aliasbase, uci:get_all(external, "alias") or {})
				aliasbase.ipaddr = dhcp_ip
				aliasbase.netmask = dhcp_mask
				aliasbase.proto = "static"
				vap = luci.http.formvalue("cbid.ffwizward.1.vap_" .. device)
				if vap then
					uci:section("network", "interface", nif .. "dhcp", aliasbase)
					uci:section("wireless", "wifi-iface", nil, {
						device     =device,
						mode       ="ap",
						encryption ="none",
						network    =nif.."dhcp",
						ssid       ="AP"..ssidshort
					})
					if has_radvd then
						uci:section("radvd", "interface", nil, {
							interface          =nif .. "dhcp",
							AdvSendAdvert      =1,
							AdvManagedFlag     =0,
							AdvOtherConfigFlag =0,
							ignore             =0
						})
						uci:section("radvd", "prefix", nil, {
							interface          =nif .. "dhcp",
							AdvOnLink          =1,
							AdvAutonomous      =1,
							AdvRouterAddr      =0,
							ignore             =0
						})
						uci:save("radvd")
					end
					tools.firewall_zone_add_interface("freifunk", nif .. "dhcp")
					uci:save("wireless")
					ifconfig.mcast_rate = nil
					ifconfig.encryption="none"
				else
					aliasbase.interface = nif
					uci:section("network", "alias", nif .. "dhcp", aliasbase)
				end
				-- Create dhcp
				local dhcpbase = uci:get_all("freifunk", "dhcp")
				util.update(dhcpbase, uci:get_all(external, "dhcp") or {})
				dhcpbase.interface = nif .. "dhcp"
				dhcpbase.force = 1
				uci:section("dhcp", "dhcp", nif .. "dhcp", dhcpbase)
				uci:set_list("dhcp", nif .. "dhcp", "dhcp_option", "119,olsr")
				-- Create firewall settings
				uci:delete_all("firewall", "rule", {
					src="freifunk",
					proto="udp",
					dest_port="53"
				})
				uci:section("firewall", "rule", nil, {
					src="freifunk",
					proto="udp",
					dest_port="53",
					target="ACCEPT"
				})
				uci:delete_all("firewall", "rule", {
					src="freifunk",
					proto="udp",
					src_port="68",
					dest_port="67"
				})
				uci:section("firewall", "rule", nil, {
					src="freifunk",
					proto="udp",
					src_port="68",
					dest_port="67",
					target="ACCEPT"
				})
				uci:delete_all("firewall", "rule", {
					src="freifunk",
					proto="tcp",
					dest_port="8082",
				})
				uci:section("firewall", "rule", nil, {
					src="freifunk",
					proto="tcp",
					dest_port="8082",
					target="ACCEPT"
				})
				-- Register splash
				uci:section("luci_splash", "iface", nil, {network=nif.."dhcp", zone="freifunk"})
				uci:save("luci_splash")
				-- Make sure that luci_splash is enabled
				sys.init.enable("luci_splash")
			end
		else
			-- Delete old splash
			uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
		end
		--Write Ad-Hoc wifi section after AP wifi section
		uci:section("wireless", "wifi-iface", nil, ifconfig)
		uci:save("network")
		uci:save("wireless")
		uci:save("network")
		uci:save("firewall")
		uci:save("dhcp")
	end)
	-- Create wired ip and firewall config
	uci:foreach("network", "interface",
		function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		if device ~= "loopback" and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			local node_ip
			node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
			node_ip6 = luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device) and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device))
			if not node_ip or not network or not network:contains(node_ip) then
				meship.tag_missing[section] = true
				node_ip = nil
				return
			end
			-- Cleanup
			tools.firewall_zone_remove_interface(device, device)
			uci:delete_all("firewall","zone", {name=device})
			uci:delete_all("firewall","forwarding", {src=device})
			uci:delete_all("firewall","forwarding", {dest=device})
			uci:delete("network", device .. "dhcp")
			-- Delete old dhcp
			uci:delete("dhcp", device)
			uci:delete("dhcp", device .. "dhcp")
			-- Delete old splash
			uci:delete_all("luci_splash", "iface", {network=device.."dhcp", zone="freifunk"})
			if has_radvd then
				uci:delete_all("radvd", "interface", {interface=device.."dhcp"})
				uci:delete_all("radvd", "interface", {interface=device})
				uci:delete_all("radvd", "prefix", {interface=device.."dhcp"})
				uci:delete_all("radvd", "prefix", {interface=device})
			end

			-- New Config
			local netconfig = uci:get_all("freifunk", "interface")
			util.update(netconfig, uci:get_all(external, "interface") or {})
			netconfig.proto = "static"
			netconfig.ipaddr = node_ip:string()
			netconfig.ip6addr = node_ip6:string()
			uci:section("network", "interface", device, netconfig)
			uci:save("network")
			if has_radvd then
				uci:section("radvd", "interface", nil, {
					interface          =device,
					AdvSendAdvert      =1,
					AdvManagedFlag     =0,
					AdvOtherConfigFlag =0,
					ignore             =0
				})
				uci:section("radvd", "prefix", nil, {
					interface          =device,
					AdvOnLink          =1,
					AdvAutonomous      =1,
					AdvRouterAddr      =0,
					ignore             =0,
				})
				uci:save("radvd")
			end
			local new_hostname = node_ip:string():gsub("%.", "-")
			uci:set("freifunk", "wizard", "hostname", new_hostname)
			uci:save("freifunk")
			tools.firewall_zone_add_interface("freifunk", device)
			uci:save("firewall")
			-- Collect MESH DHCP IP NET
			local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
			if client then
				local dhcpmeshnet = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
				local ifacelist = uci:get_list("manager", "heartbeat", "interface") or {}
				table.insert(ifacelist,device .. "dhcp")
				uci:set_list("manager", "heartbeat", "interface", ifacelist)
				uci:save("manager")
				if dhcpmeshnet then
					if not dhcpmeshnet:minhost() or not dhcpmeshnet:mask() then
						dhcpmesh.tag_missing[section] = true
						dhcpmeshnet = nil
						return
					end
					dhcp_ip = dhcpmeshnet:minhost():string()
					dhcp_mask = dhcpmeshnet:mask():string()
				else
					local subnet_prefix = tonumber(uci:get("freifunk", community, "splash_prefix")) or 27
					local pool_network = uci:get("freifunk", community, "splash_network") or "10.104.0.0/16"
					local pool = luci.ip.IPv4(pool_network)
					local ip = tostring(node_ip)
					if pool and ip then
						local hosts_per_subnet = 2^(32 - subnet_prefix)
						local number_of_subnets = (2^pool:prefix())/hosts_per_subnet
						local seed1, seed2 = ip:match("(%d+)%.(%d+)$")
						if seed1 and seed2 then
							math.randomseed(seed1 * seed2)
						end
						local subnet = pool:add(hosts_per_subnet * math.random(number_of_subnets))
						dhcp_ip = subnet:network(subnet_prefix):add(1):string()
						dhcp_mask = subnet:mask(subnet_prefix):string()
					end
				end
				if dhcp_ip and dhcp_mask then
					-- Create alias
					local aliasbase = uci:get_all("freifunk", "alias")
					util.update(aliasbase, uci:get_all(external, "alias") or {})
					aliasbase.interface = device
					aliasbase.ipaddr = dhcp_ip
					aliasbase.netmask = dhcp_mask
					aliasbase.proto = "static"
					uci:section("network", "alias", device .. "dhcp", aliasbase)
					-- Create dhcp
					local dhcpbase = uci:get_all("freifunk", "dhcp")
					util.update(dhcpbase, uci:get_all(external, "dhcp") or {})
					dhcpbase.interface = device .. "dhcp"
					dhcpbase.force = 1
					uci:section("dhcp", "dhcp", device .. "dhcp", dhcpbase)
					uci:set_list("dhcp", device .. "dhcp", "dhcp_option", "119,olsr")
					-- Create firewall settings
					uci:delete_all("firewall", "rule", {
						src="freifunk",
						proto="udp",
						dest_port="53"
					})
					uci:section("firewall", "rule", nil, {
						src="freifunk",
						proto="udp",
						dest_port="53",
						target="ACCEPT"
					})
					uci:delete_all("firewall", "rule", {
						src="freifunk",
						proto="udp",
						src_port="68",
						dest_port="67"
					})
					uci:section("firewall", "rule", nil, {
						src="freifunk",
						proto="udp",
						src_port="68",
						dest_port="67",
						target="ACCEPT"
					})
					uci:delete_all("firewall", "rule", {
						src="freifunk",
						proto="tcp",
						dest_port="8082",
					})
					uci:section("firewall", "rule", nil, {
						src="freifunk",
						proto="tcp",
						dest_port="8082",
						target="ACCEPT"
					})
					-- Register splash
					uci:section("luci_splash", "iface", nil, {network=device.."dhcp", zone="freifunk"})
					uci:save("luci_splash")
					-- Make sure that luci_splash is enabled
					sys.init.enable("luci_splash")
				end
			end
			uci:save("wireless")
			uci:save("network")
			uci:save("firewall")
			uci:save("dhcp")
		end
	end)

	-- Create wireless olsrv4 config
	uci:foreach("wireless", "wifi-device",
	function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		local node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
		if not node_ip or not network or not network:contains(node_ip) then
			meship.tag_missing[section] = true
			node_ip = nil
			return
		end
		-- rename the wireless interface s/wifi/wireless/
		local nif
		if string.find(device, "wifi") then
			nif = string.gsub(device,"wifi", netname)
		elseif string.find(device, "wl") then
			nif = string.gsub(device,"wl", netname)
		elseif string.find(device, "wlan") then
			nif = string.gsub(device,"wlan", netname)
		elseif string.find(device, "radio") then
			nif = string.gsub(device,"radio", netname)
		end

		-- Write new interface
		local olsrifbase = uci:get_all("freifunk", "olsr_interface")
		util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
		olsrifbase.interface = nif
		olsrifbase.ignore    = "0"
		uci:section("olsrd", "Interface", nil, olsrifbase)
		-- Collect MESH DHCP IP NET
		local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
		if client then
			local dhcpmesh = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
			if dhcpmesh then
				local mask = dhcpmesh:mask():string()
				local network = dhcpmesh:network():string()
				uci:section("olsrd", "Hna4", nil, {
					netmask  = mask,
					netaddr  = network
				})
				uci:foreach("olsrd", "LoadPlugin",
					function(s)		
						if s.library == "olsrd_p2pd.so.0.1.0" then
							uci:set("olsrd", s['.name'], "ignore", "0")
							local nonolsr = uci:get("olsrd", s['.name'], "NonOlsrIf") or ""
							vap = luci.http.formvalue("cbid.ffwizward.1.vap_" .. device)
							if vap then
								nonolsr = nif.."dhcp "..nonolsr
							else
								nonolsr = nif.." "..nonolsr
							end
							uci:set("olsrd", s['.name'], "NonOlsrIf", nonolsr)
						end
					end)
			end
		end
	end)
	-- Create wired olsrdv4 config
	uci:foreach("network", "interface",
		function(sec)
		local device = sec[".name"]
		if device ~= "loopback" and not string.find(device, "gvpn") and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			local node_ip
			if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
				return
			end
			node_ip = luci.http.formvalue("cbid.ffwizward.1.meship_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.meship_" .. device))
			if not node_ip or not network or not network:contains(node_ip) then
				meship.tag_missing[section] = true
				node_ip = nil
				return
			end
			-- Write new interface
			local olsrifbase = uci:get_all("freifunk", "olsr_interface")
			util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
			olsrifbase.interface = device
			olsrifbase.ignore    = "0"
			uci:section("olsrd", "Interface", nil, olsrifbase)
			-- Collect MESH DHCP IP NET
			local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
			if client then
				local dhcpmesh = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv4(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
				if dhcpmesh then
					local mask = dhcpmesh:mask():string()
					local network = dhcpmesh:network():string()
					uci:section("olsrd", "Hna4", nil, {
						netmask  = mask,
						netaddr  = network
					})
					uci:foreach("olsrd", "LoadPlugin",
						function(s)		
							if s.library == "olsrd_p2pd.so.0.1.0" then
								uci:set("olsrd", s['.name'], "ignore", "0")
								local nonolsr = uci:get("olsrd", s['.name'], "NonOlsrIf") or ""
								uci:set("olsrd", s['.name'], "NonOlsrIf", device .." ".. nonolsr)
							end
						end)
				end
			end
		end
	end)
	

	-- Create wireless olsrv6 config
	uci:foreach("wireless", "wifi-device",
	function(sec)
		local device = sec[".name"]
		if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
			return
		end
		local node_ip6 = luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device)
		-- and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device))
		if not node_ip6 then
			meship6.tag_missing[section] = true
			node_ip6 = nil
			return
		end
		-- rename the wireless interface s/wifi/wireless/
		local nif
		if string.find(device, "wifi") then
			nif = string.gsub(device,"wifi", netname)
		elseif string.find(device, "wl") then
			nif = string.gsub(device,"wl", netname)
		elseif string.find(device, "wlan") then
			nif = string.gsub(device,"wlan", netname)
		elseif string.find(device, "radio") then
			nif = string.gsub(device,"radio", netname)
		end

		-- Write new interface
		local olsrifbase = uci:get_all("freifunk", "olsr_interface")
		util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
		olsrifbase.interface = nif
		olsrifbase.Ip4Broadcast = ''
		olsrifbase.ignore    = "0"
		uci:section("olsrdv6", "Interface", nil, olsrifbase)
		-- Collect MESH DHCP IP NET
--		local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
--		if client then
--			local dhcpmesh = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
--			if dhcpmesh then
--				local mask = dhcpmesh:mask():string()
--				local network = dhcpmesh:network():string()
--				uci:section("olsrdv6", "Hna6", nil, {
--					netmask  = mask,
--					netaddr  = network
--				})
--				uci:foreach("olsrdv6", "LoadPlugin",
--					function(s)
--						if s.library == "olsrd_p2pd.so.0.1.0" then
--							uci:set("olsrd", s['.name'], "ignore", "0")
--							uci:set("olsrd", s['.name'], "NonOlsrIf", nif)
--						end
--					end)
--			end
--		end
	end)
	-- Create wired olsrdv6 config
	uci:foreach("network", "interface",
		function(sec)
		local device = sec[".name"]
		if device ~= "loopback" and not string.find(device, "gvpn") and not string.find(device, "wifi") and not string.find(device, "wl") and not string.find(device, "wlan") and not string.find(device, "wireless") and not string.find(device, "radio") then
			local node_ip6
			if not luci.http.formvalue("cbid.ffwizward.1.device_" .. device) then
				return
			end
			node_ip6 = luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device)
			-- and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.meship6_" .. device))
			if not node_ip6 then
				meship6.tag_missing[section] = true
				node_ip6 = nil
				return
			end
			-- Write new interface
			local olsrifbase = uci:get_all("freifunk", "olsr_interface")
			util.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
			olsrifbase.interface = device
			olsrifbase.ignore    = "0"
			olsrifbase.Ip4Broadcast = ''
			olsrifbase.Mode = 'ether'
			uci:section("olsrdv6", "Interface", nil, olsrifbase)
			-- Collect MESH DHCP IP NET
--			local client = luci.http.formvalue("cbid.ffwizward.1.client_" .. device)
--			if client then
--				local dhcpmesh = luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device) and ip.IPv6(luci.http.formvalue("cbid.ffwizward.1.dhcpmesh_" .. device))
--				if dhcpmesh then
--					local mask = dhcpmesh:mask():string()
--					local network = dhcpmesh:network():string()
--					uci:section("olsrdv6", "Hna6", nil, {
--						netmask  = mask,
--						netaddr  = network
--					})
--					uci:foreach("olsrdv6", "LoadPlugin",
--						function(s)		
--							if s.library == "olsrd_p2pd.so.0.1.0" then
--								uci:set("olsrdv6", s['.name'], "ignore", "0")
--								uci:set("olsrdv6", s['.name'], "NonOlsrIf", device)
--							end
--						end)
--				end
--			end
		end
	end)
	


