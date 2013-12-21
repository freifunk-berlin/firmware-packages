#!/usr/bin/env lua

local uci = require "luci.model.uci".cursor()
local ip = require "luci.ip"
local util = require "luci.util"
local json = require "luci.json"
local string = require "string"
local sys = require "luci.sys"
local netm = require "luci.model.network".init()
local net = netm:get_network("lan")
local device = net and net:get_interface()

local enable = uci:get("auto_ipv6_node", "olsr_node", "enable")
if not enable == 1 then return end

local jsonreq = util.exec("echo /hna | nc ::1 9090 2>/dev/null") or {}
local hna6 = json.decode(jsonreq)
if not hna6 or #hna6.hna == 0 then return end
local jsonreq = util.exec("echo /routes | nc ::1 9090 2>/dev/null") or {}
local routes6 = json.decode(jsonreq)
if not routes6 or #routes6.routes == 0 then return end
local default_etx = 1000000
local prefix = {}
local ula = ip.IPv6("fd00::/8")
local uciprefix = {}
for _, p in ipairs(uci:get_list("network","lan","ip6prefix")) do
	uciprefix[#uciprefix+1] = {net=p}
end
local ula_prefix = uci:get("network","globals","ula_prefix")
if ula_prefix then
	ula_prefix = ip.IPv6(ula_prefix)
end
for _, p in ipairs(hna6.hna) do
	prefix[#prefix+1] = {}
	prefix[#prefix].gateway = p.gateway
	prefix[#prefix].net = p.destination.."/"..p.genmask
	prefix[#prefix].destination = p.destination
	prefix[#prefix].genmask = p.genmask
end

for _, r in ipairs(routes6.routes) do
	for _, p in ipairs(prefix) do
		if r.destination == p.gateway then
			p.metric = r.metric
			p.rtpMetricCost = r.rtpMetricCost
		end
	end
end

for _, p in ipairs(prefix) do
	if p.genmask > 0 and p.genmask < 49 then
		local ipnet = ip.IPv6(p.net)
		if not ula:contains(ipnet) then
			local con = 0
			print("Find:",p.net,p.gateway,p.metric,p.rtpMetricCost)
			for i, u in ipairs(uciprefix) do
				ipp = ip.IPv6(u.net)
				if ipnet:contains(ipp) then
					if con == 0 then
						print("Configured:",u.net)
						uciprefix[i].con = 1
						uciprefix[i].gateway=p.gateway
						con=1
					else
						print("Configured DUP!:",u.net)
						uciprefix[i].del = 1
					end
				end
			end
			if con == 0 then
				print("Not Configured:",p.net)
				local rand = sys.exec("head -n 1 /dev/urandom 2>/dev/null | md5sum | cut -b 1-4")
				local net = string.gsub(p.destination,"::",":"..rand.."::/61")
				net = ip.IPv6(net)
				if net:is6() then
					net = net:network()
					print("New Configuration:",net:string().."/61")
					uciprefix[#uciprefix+1] = { net=net:string().."/61",gateway=p.gateway,con=0 }
				end
			end
		end
	end
end

for _, p in ipairs(prefix) do
	if p.genmask ~= 0 then
		local ipnet = ip.IPv6(p.net)
		for i, u in ipairs(uciprefix) do
			ipp = ip.IPv6(u.net)
			if ipnet:contains(ipp) or ipnet == ipp then
				if u.del ~= 1 and ip.IPv6(u.gateway) ~= ip.IPv6(p.gateway) then
					uciprefix[i].del = 1
					print("Olsr DUP!:",p.net)
				end
			end
		end
	end
end

local uci_rewrite = 0
local uciprefix_n = {}
local ucihna6 = {}
for _, p in ipairs(uciprefix) do
	if not p.con then
		uci_rewrite = 1
		print("Del uciprefix no Hna6:",p.net)
	elseif p.con == 0 then
		uci_rewrite = 1
		print("New uciprefix:",p.net)
		table.insert(uciprefix_n,p.net)
		ucihna6[#ucihna6+1] = {
			prefix = ipp:prefix(),
			netaddr = ipp:network():string()
		}
	elseif p.del == 1 then
		print("Del uciprefix DUP!:",p.net)
		uci_rewrite = 1
	else
		table.insert(uciprefix_n,p.net)
		local ipp = ip.IPv6(p.net)
		ucihna6[#ucihna6+1] = {
			prefix = ipp:prefix(),
			netaddr = ipp:network():string()
		}
	end
end
if uci_rewrite == 1 then
	if #uciprefix_n > 0 then
		uci:set_list("network","lan","ip6prefix",uciprefix_n)
	else
		uci:delete("network","lan","ip6prefix")
	end
	uci:save("network")
	uci:commit("network")


	uci:foreach("olsrd", "LoadPlugin",
	function(s)
		if s.library == "olsrd_nameservice.so.0.3" then
			--todo
			--bug: in olsrd.init:39 do not match ip6 addr
			--fix: str%%[! 	0-9A-Za-z./|:_-[]]*
			--bug: in nameservice.c:378 do not match ip6 addr
			--fix: ?
			--uci:add_list("olsrd", s['.name'], "service", "http://["..p.netaddr.."1]:80|tcp|"..sys.hostname().." on "p.netaddr)
			local hosts = {}
			for i, p in ipairs(ucihna6) do
				local net = ip.IPv6(p.netaddr.."/"..p.prefix)
				hosts[#hosts+1] = net:minhost():string().." pre"..i.."."..sys.hostname()
			end
			uci:set_list("olsrd", s['.name'], "hosts", hosts)
		end
	end)

	uci:delete_all("olsrd", "Hna6")
	if ula_prefix:is6() then
		ucihna6[#ucihna6+1] = {
			prefix = ula_prefix:prefix(),
			netaddr = ula_prefix:network():string()
		}
	end
	for _, p in ipairs(ucihna6) do
		print("Olsr Hna6:",p.netaddr)
		uci:section("olsrd", "Hna6", nil, {
				prefix = p.prefix,
				netaddr = p.netaddr
		})
	end
	uci:save("olsrd")
	uci:commit("olsrd")
	util.exec("/etc/init.d/network reload")
	util.exec("/bin/sleep 3")
	util.exec("/etc/init.d/olsrd restart")
	util.exec("/etc/init.d/6relayd reload")
end

