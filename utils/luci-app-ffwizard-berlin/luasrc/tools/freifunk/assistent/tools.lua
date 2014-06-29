local uci = require "luci.model.uci".cursor()
local sharenet = uci:get("freifunk","wizard","sharenet")

module "luci.tools.freifunk.assistent.tools"

function configureWatchdog()
	if (sharenet) then
		uci:section("freifunk-watchdog", "process", nil, {
			process="openvpn",
			initscript="/etc/init.d/openvpn"
		})
	end
	uci:save("freifunk-watchdog")
end

function configureQOS()
	if (sharenet) then
		uci:delete("qos","wan")
		uci:delete("qos","lan")
		uci:section("qos", 'interface', "wan", {
		enabled = "1",
			classgroup = "Default",
		})
	end
	uci:save("qos")
end
function configureP2PBlock()
	if (sharenet) then
		uci:set("freifunk_p2pblock", "p2pblock", "interface", "wan")
		uci:save("freifunk_p2pblock")
	end
end
