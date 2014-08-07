local uci = require "luci.model.uci".cursor()
local tools = require "luci.tools.freifunk.assistent.ffwizard"
local sharenet = uci:get("freifunk","wizard","sharenet") == "1"
module ("luci.tools.freifunk.assistent.firewall",package.seeall)


function configureFirewall()
	tools.firewall_zone_add_interface("freifunk", "dhcp")                                       
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
	uci:foreach("firewall", "defaults",                                                 
        	function(section)                                                                    
                	uci:set("firewall", section[".name"], "drop_invalid", "0")                             
        	end)
	
	local has_advanced = false                                                           
	uci:foreach("firewall", "advanced",
        	function(section) has_advanced = true end)
	if not has_advanced then
        	uci:section("firewall", "advanced", nil,
               	{ tcp_ecn = "0", ip_conntrack_max = "8192", tcp_westwood = "1" }) 
	end


	if (sharenet == "1") then
		uci:delete_all("firewall","zone", {name="wan"})
		uci:section("firewall", "zone", nil, {
			masq	= "1",
			input = "REJECT",
			forward = "REJECT",
			name = "wan",
			output = "ACCEPT",
			network = "wan"
		})
		uci:delete_all("firewall","forwarding", {src="freifunk", dest="wan"})
		uci:section("firewall", "forwarding", nil, {src="freifunk", dest="wan"})
		uci:delete_all("firewall","forwarding", {src="wan", dest="freifunk"})
		uci:section("firewall", "forwarding", nil, {src="wan", dest="freifunk"})
		uci:delete_all("firewall","forwarding", {src="lan", dest="wan"})
		uci:section("firewall", "forwarding", nil, {src="lan", dest="wan"})
		uci:foreach("firewall", "zone",
			function(s)	
				if s.name == "wan" then
					uci:set("firewall", s['.name'], "local_restrict", "1")
					uci:set("firewall", s['.name'], "masq", "1")
					return false
				end
			end)
		uci:foreach("firewall", "zone",
			function(s)	
				if s.name == "wan" then
					uci:set("firewall", s['.name'], "input", "ACCEPT")
					return false
				end
			end)
		tools.firewall_zone_add_interface("freifunk", "ffvpn")
		ovpn_server_list = uci:get_list("openvpn","ffvpn","remote")
		for i,v in ipairs(ovpn_server_list) do
			uci:section("firewall", "rule", nil, {
				--name="Reject-VPN-over-ff",
				dest="freifunk",
				family="ipv4",
				proto="udp",
				dest_ip=v,
				--dest_port="1194",
				target="REJECT"
			})
		end
	else
		uci:delete_all("firewall", "forwarding", {src="freifunk", dest="wan"})
		uci:foreach("firewall", "zone", 
       		 	function(s) 
                		if s.name == "wan" then 
                        		uci:delete("firewall", s['.name'], "local_restrict")
                        		return false
                		end 
			end)
	end

	uci:save("firewall")
end

function configurePolicyRouting()
	if (sharenet == "1") then
	        uci:set("freifunk-policyrouting","pr","enable","1")
        	uci:set("freifunk-policyrouting","pr","strict","1")
	        uci:set("freifunk-policyrouting","pr","fallback","1")
        	uci:set("freifunk-policyrouting","pr","zones", "freifunk")
	else 
        	uci:set("freifunk-policyrouting","pr","enable","0")
        	uci:delete_all("network","rule") 
	end
	uci:save("network")
	uci:save("freifunk-policyrouting")
end
