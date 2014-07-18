#!/usr/bin/env lua

local sys = require "luci.sys"
local fs = require "luci.fs"
local utl = require "luci.util"
local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local json = require "luci.json"
local string = require "string"
local ntm = require "luci.model.network"
local profiles = "/etc/config/profile_"
local ready = false

local has_6relayd = fs.access("/usr/sbin/6relayd")
local has_odhcpd = fs.access("/usr/sbin/odhcpd")

function iwscanlist(ifname,times)
	local iw = sys.wifi.getiwinfo(ifname)
	local i, k, v
	local l = { }
	local s = { }

	for i = 1, times do
		for k, v in ipairs(iw.scanlist or { }) do
			if not s[v.bssid] then
				l[#l+1] = v
				s[v.bssid] = ""
			end
		end
	end

	return iw,l
end

function valid_channel(iw,channel)
	for _, f in ipairs(iw and iw.freqlist or { }) do 
		if f.channel == channel and not f.restricted then 
			return true
		end
	end
	return false
end

function get_profiles()
	local list = fs.glob(profiles .. "*") or {}
	local pft = {}

	for k,v in ipairs(list) do
		pft[#pft+1] = {}
		local n = string.gsub(v, profiles, "")
		pft[#pft].uciname = n
		pft[#pft].name = uci:get_first("profile_"..n, "community", "name") or ""
		pft[#pft].ssid = uci:get_first("profile_"..n, "community", "ssid") or ""
		pft[#pft].bssid = string.upper(uci:get_first("profile_"..n, "defaults", "bssid") or "")
		pft[#pft].channel = uci:get_first("profile_"..n, "defaults", "channel") or ""
	end

	return pft
end

function get_wconf(iw,tbl,pft)
	local wconf = {}

	for i, net in ipairs(tbl) do
		if net.mode == "Ad-Hoc" then
			if valid_channel(iw,net.channel) then
				print(net.quality,net.bssid,net.channel,net.signal.." dB",net.quality,net.quality_max.." max")
				wconf.mode = "adhoc"
				wconf.ssid = net.ssid
				wconf.bssid = net.bssid
				wconf.channel = net.channel
				wconf.profile = "berlin"
				for i, profile in ipairs(pft) do
					--print("profile"..profile.ssid,net.ssid)
	--				if net.ssid == profile.ssid then
	--					print("ssid profile "..profile.uciname,"net "..net.ssid,net.bssid)
	--				end
				end
				for i, profile in ipairs(pft) do
					--print("profile: "..profile.bssid.."net: "..net.bssid)
	--				if net.bssid == profile.bssid then
	--					print("bssid profile "..profile.uciname,"net "..net.ssid,net.bssid)
	--				end
				end
				for i, profile in ipairs(pft) do
					--print("profile "..profile.bssid,"net "..net.bssid)
					local pssid = string.gsub(profile.ssid,"%..*","")
					local nssid = string.gsub(net.ssid,"%..*","")
	--				if nbssid == pbssid then
	--					print("ssid profile %..*:[] "..profile.uciname,"profile "..profile.ssid,"net "..net.ssid)
	--				end
				end
				for i, profile in ipairs(pft) do
					--print("profile "..profile.bssid,"net "..net.bssid)
					local pbssid = string.gsub(profile.bssid,"%x%x:","",1)
					local nbssid = string.gsub(net.bssid,"%x%x:","",1)
	--				if nbssid == pbssid then
	--					print("bssid profile %x%x:[] "..profile.uciname,"profile"..profile.bssid,"net "..net.bssid)
	--				end
				end
	
				return  wconf
			else
				print(net.quality,net.bssid,net.channel,net.signal.." dB",net.quality,net.quality_max.." max not valid")
			end
		end
	end
	wconf.profile = "berlin"
	wconf.mode = "adhoc"
	local ssid = "ch13.freifunk.net"
	local channel = 13
	local bssid = "D2:CA:FF:EE:BA:BE"
	if not valid_channel(iw,channel) then
		if valid_channel(iw,36) then
			channel = 36
			bssid = "02:36:CA:FF:EE:EE"
			ssid = "ch36.freifunk.net"
		elseif valid_channel(iw,100) then
			channel = 100
			bssid = "12:00:CA:FF:EE:EE"
			ssid = "ch100.freifunk.net"
		end
	end
	wconf.ssid = ssid
	wconf.bssid = bssid
	wconf.channel = channel
	return wconf
end



local profiles = get_profiles()
ntm.init(uci)
local devices = ntm:get_wifidevs()
local dev
local profile_name
local profile_suffix
local external
local rand = sys.exec("echo -n $(head -n 1 /dev/urandom 2>/dev/null | md5sum | cut -b 1-4)")

--Add LAN to olsrd6 p2p
local p2p_if = {}
table.insert(p2p_if,"lan")

--Add Define 
local rifn = {}
table.insert(rifn,"lan")

--Delete all olsrd6 Interfaces
uci:delete_all("olsrd6", "Interface")
uci:save("olsrd6")

for i,dev in ipairs(devices) do
	seq = i - 1
	print(dev:get("disabled"))
	if dev:get("disabled") == "1" then
		dev:set("disabled", "0")
		dev:set("country", "DE")
		ntm:save("wireless")
		sys.exec("/sbin/wifi reload_legacy")
		for _, net in ipairs(dev:get_wifinets()) do
			local ifc = net:get_interface()
			local iw, scan = iwscanlist(ifc.ifname,3)
			table.sort(scan, function(a, b) 
				return tonumber(a["quality"]) > tonumber(b["quality"])
			end)
			local wificonfig = get_wconf(iw,scan,profiles)
			profile_name = wificonfig.profile or "berlin"
			profile_suffix = wificonfig.suffix or "olsr"
			print(wificonfig.profile,wificonfig.ssid,wificonfig.bssid,wificonfig.channel)
			local ssid = wificonfig.ssid
			local bssid = wificonfig.bssid
			local channel = wificonfig.channel
			external = "profile_"..profile_name
			dev:set("channel", channel)
			dev:set("noscan",true)
			dev:set("distance",1000)
			local hwmode = dev:get("hwmode")
			if string.find(hwmode, "n") then
				has_n = "n"
			end
			if has_n then
				local ht40plus = {
					1,2,3,4,5,6,7,
					36,44,52,60,100,108,116,124,132
				}
				for i, v in ipairs(ht40plus) do
					if v == channel then
						dev:set("htmode","HT40+")
					end
				end
				local ht40minus = {
					8,9,10,11,12,13,14,
					40,48,56,64,104,112,120,128,136
				}
				for i, v in ipairs(ht40minus) do
					if v == channel then
						dev:set("htmode","HT40-")
					end
				end
				local ht20 = {
					140
				}
				for i, v in ipairs(ht20) do
					if v == channel then
						dev:set("htmode","HT20'")
					end
				end
			end
			net:set("ssid",ssid)
			net:set("bssid",bssid)
			net:set("mode",wificonfig.mode)
			net:set("network","wireless"..seq)
			local ssiddot = string.find(ssid,'%..*')
			local ssidshort = ""
			local vap_ssid = ""
			if ssiddot then
				vap_ssid = "AP-"..rand.."-"..channel..string.sub(ssid,ssiddot)
			else
				vap_ssid = "AP-"..rand.."-"..channel.."."..ssid
			end
			uci:section("wireless", "wifi-iface", nil, {
				device="radio"..seq,
				mode="ap",
				encryption ="none",
				network="wireless"..seq.."dhcp",
				ssid=vap_ssid
			})
			table.insert(p2p_if,"wireless"..seq.."dhcp")

			ntm:save("wireless")
	
			uci:section("network","interface","wireless"..seq, {
				proto = "static",
				ip6assign = 64
			})
			uci:set_list("network","wireless"..seq,"dns", { "2002:d596:2a92:1:71:53::", "2002:5968:c28e::53" })
			uci:section("network","interface","wireless"..seq.."dhcp", {
				proto = "static",
				ip6assign = 64
			})

			uci:save("network")
	
			table.insert(rifn,"wireless"..seq)
			table.insert(rifn,"wireless"..seq.."dhcp")

			local olsrifbase = {}
			olsrifbase.interface = "wireless"..seq
			olsrifbase.ignore = "0"
			uci:section("olsrd6", "Interface", nil, olsrifbase)
			uci:save("olsrd6")
			ready = true
		end
	end
end

if ready then

	--save network
	uci:commit("network")

	--save wireless
	ntm:commit("wireless")

	--uhttpd is listen on ipv6
	uci:set("uhttpd", "main", "listen_http", 80)
	uci:set("uhttpd", "main", "listen_https", 443)
	uci:save("uhttpd")
	uci:commit("uhttpd")

	--set community profile
	local community = uci:get_all(external, "profile")
	uci:tset("freifunk", "community", community)
	uci:set("freifunk", "community", "name", profile_name)

	--save freifunk
	uci:save("freifunk")
	uci:commit("freifunk")

	--set olsrd6 base config
	uci:delete_all("olsrd6", "olsrd")
	local olsrbase = uci:get_all("freifunk", "olsrd") or {}
	utl.update(olsrbase, uci:get_all(external, "olsrd") or {})
	--olsrbase.IpVersion = "6"
	olsrbase.LinkQualityAlgorithm = "etx_ffeth"
	olsrbase.NatThreshold = nil
	uci:section("olsrd6", "olsrd", nil, olsrbase)

	--set olsrd6 nameservice defaults
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_nameservice.so.0.3"})
	uci:section("olsrd6", "LoadPlugin", nil, {
		library = "olsrd_nameservice.so.0.3",
		suffix = "." .. profile_suffix,
		hosts_file = "/tmp/hosts/olsr",
		latlon_file = "/var/run/latlon.js",
		services_file = "/var/etc/services.olsr"
	})

	--set olsrd6 interface defaults
	local olsrifbase = uci:get_all("freifunk", "olsr_interface") or {}
	utl.update(olsrifbase, uci:get_all(external, "olsr_interface") or {})
	olsrifbase.Ip4Broadcast = nil
	uci:section("olsrd6", "InterfaceDefaults", nil, olsrifbase)
	uci:delete_all("olsrd6", "LoadPlugin", {library="olsrd_jsoninfo.so.0.0"})

	--set olsrd6 jsoninfo listen on ipv6
	uci:section("olsrd6", "LoadPlugin", nil, {
		library = "olsrd_jsoninfo.so.0.0",
		ignore = 0,
		accept = "::"
	})

	--add lan to olsr interfaces
	local olsrifbase = {}
	olsrifbase.interface = "lan"
	olsrifbase.ignore = "0"
	olsrifbase.Mode = 'ether'
	uci:section("olsrd6", "Interface", nil, olsrifbase)
	
	--set olsrd6 p2p listen on ipv6
	uci:section("olsrd6", "LoadPlugin", nil, {
		library = "olsrd_p2pd.so.0.1.0",
		ignore = 1,
		P2pdTtl = 10,
		UdpDestPort = "ff02::fb 5353",
		NonOlsrIf = p2p_if
	})

	--save olsrd6
	uci:save("olsrd6")
	uci:commit("olsrd6")

	if has_6relayd then
		uci:set_list("6relayd","default","network",rifn)
		uci:save("6relayd")
	end

	-- Import hosts and set domain
	uci:foreach("dhcp", "dnsmasq", function(s)
		uci:set("dhcp", s[".name"], "local", "/" .. profile_suffix .. "/")
		uci:set("dhcp", s[".name"], "domain", profile_suffix)
	end)

	if has_odhcpd then
		for i,ifn in ipairs(rifn) do
			if not uci:get("dhcp", ifn) then
				uci:section("dhcp", "dhcp", ifn, { })
			end
			uci:set("dhcp", ifn, "dhcpv6", "server")
			uci:set("dhcp", ifn, "ra", "server")
			uci:set("dhcp", ifn, "domain", profile_suffix)
			uci:set("dhcp", ifn, "ra_preference", "low")
		end
	end

	--save system
	uci:save("dhcp")
	uci:commit("dhcp")

	local new_hostname = "OpenWrt-"..rand
	uci:foreach("system", "system",
		function(s)
			-- Make set timzone and zonename
			uci:set("system", s[".name"], "zonename", "Europe/Berlin")
			uci:set("system", s[".name"], "timezone", 'CET-1CEST,M3.5.0,M10.5.0/3')
			-- Set uniq hostname
			uci:set("system", s[".name"], "hostname", new_hostname)
			sys.hostname(new_hostname)
			-- Set hostname
			uci:set("system", s[".name"], "latitude", community.latitude)
			uci:set("system", s[".name"], "longitude", community.longitude)
		end)

	--save system
	uci:save("system")
	uci:commit("system")

	--save system
	uci:commit("6relayd")

	--restart deamons
	luci.sys.call("(/etc/init.d/network restart) >/dev/null 2>/dev/null")
	luci.sys.call("/bin/sleep 3")
	luci.sys.call("(/etc/init.d/olsrd6 restart) >/dev/null 2>/dev/null")
	if has_6relayd then
		luci.sys.call("(/etc/init.d/6relayd restart) >/dev/null 2>/dev/null")
	end
	if has_odhcpd then
		luci.sys.call("(/etc/init.d/odhcpd restart) >/dev/null 2>/dev/null")
	end
	luci.sys.call("(/etc/init.d/uhttpd restart) >/dev/null 2>/dev/null")
	luci.sys.call("(/etc/init.d/dnsmasq restart) >/dev/null 2>/dev/null")

else

	--revert saved configs
	uci:revert("network")
	uci:revert("wireless")
	uci:revert("uhttpd")
	uci:revert("freifunk")
	uci:revert("olsrd6")
	uci:revert("dhcp")
	uci:revert("system")
	if has_6relayd then
		uci:revert("6relayd")
	end

end

