#!/bin/sh

if [ -z $route_net_gateway ] ; then
	logger -t up-down-ffvpn "no gateway ip in main routing table!"
	exit 1
fi

if [ $(uci get freifunk-policyrouting.pr.enable) = 0 ] ; then
	logger -t up-down-ffvpn "no policy routing freifunk-policyrouting.pr.enable=0"
	exit 0
fi

table="olsr-default"
dev="$1"
remote="$5"

(
	sysctl -w "net.ipv6.conf.$dev.disable_ipv6=1"
	if [ -n "$table" ] ; then
		sleep 2
		ugw="$route_net_gateway"
		gw="$route_vpn_gateway"
		src="$ifconfig_local"
		mask="$ifconfig_netmask"
		eval $(ipcalc.sh "$src" "$mask")
		net="$NETWORK/$PREFIX"
		logger -t up-down-ffvpn "ugw: $ugw dev: $dev remote: $remote gw: $gw src: $src mask: $mask"
		ip route add "$net" dev "$dev" src "$src" table "$table"
		#ip route add $remote_1 via $ugw table main
		#ip route add default via $ugw table default
		ip route del 0.0.0.0/1 via "$gw" dev "$dev"
		ip route del 128.0.0.0/1 via "$gw" dev "$dev"
		ip route add default via "$gw" dev "$dev" table "$table" metric 10
		ip rule list | grep -q "iif $dev lookup $table" || \
		ip rule add pref 20000 iif "$dev" lookup "$table"
		ip rule list | grep -q "iif $dev unreachable" || \
		ip rule add pref 20001 iif "$dev" unreachable
		#route SIP not over vpn
		# dus.net
		ip rule list | grep -q '83.125.8.0/22' || \
		ip rule add pref 5000 to 83.125.8.0/22 lookup main
		# pbx-network.de
		ip rule list | grep -q '46.182.250.0/25' || \
		ip rule add pref 5000 to 46.182.250.0/25 lookup main 
		# pbx-network.de
		ip rule list | grep -q '178.238.128.0/20' || \
		ip rule add pref 5000 to 178.238.128.0/20 lookup main
		# freevoipdeal
		ip rule list | grep -q '77.72.174.0/24' || \
		ip rule add pref 5000 to 77.72.174.0/24 lookup main
		# sipgate
		ip rule list | grep -q '217.10.64.0/20' || \
		ip rule add pref 5000 to 217.10.64.0/20 lookup main
	fi
) >/tmp/ffvpn-up.log 2>&1 &

exit 0
