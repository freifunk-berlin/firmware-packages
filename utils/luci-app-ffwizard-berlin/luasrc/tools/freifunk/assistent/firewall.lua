local uci = require "luci.model.uci".cursor()
local tools = require "luci.tools.freifunk.assistent.tools"
local sharenet = uci:get("ffwizard","settings","sharenet")

module ("luci.tools.freifunk.assistent.firewall", package.seeall)

function prepareFirewall()
	local c = uci.cursor()
	local community = "profile"..c:get("freifunk","community","name")

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

	c:save("firewall")
end


function configureFirewall()
	tools.firewall_zone_add_interface("freifunk", "dhcp")
	if (sharenet == "1") then
		tools.firewall_zone_add_interface("freifunk", "tunl0")
		tools.firewall_zone_add_interface("freifunk", "ffvpn")
		ovpn_server_list = uci:get_list("openvpn","ffvpn","remote")
		for i,v in ipairs(ovpn_server_list) do
			uci:section("firewall", "rule", nil, {
				name="Reject-VPN-over-ff-"..i,
				dest="freifunk",
				family="ipv4",
				proto="udp",
				dest_ip=v,
				target="REJECT"
			})
		end
	end
	uci:delete_all("firewall", "forwarding", {src="freifunk", dest="wan"})
	uci:save("firewall")
end
