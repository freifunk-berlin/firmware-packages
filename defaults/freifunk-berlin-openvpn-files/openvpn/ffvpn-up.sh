#!/bin/sh

. /lib/functions.sh
if [ -z $route_net_gateway ] ; then
	logger -p debug -t up-down-ffvpn "no route_net_gateway env var from openvpn!"
	route_net_gateway=$(ip route show table main | grep default | cut -d ' ' -f 3)
	if [ -z "$route_net_gateway" ] ; then
		logger -p debug -t up-down-ffvpn "no gateway ip in main routing table!"
		route_net_gateway=$(ip route show table default | grep default | cut -d ' ' -f 3)
		if [ -z "$route_net_gateway" ] ; then
			logger -p err -t up-down-ffvpn "no gateway ip in main or default routing table!"
			exit 1
		fi
	fi
fi

config_load freifunk-policyrouting

config_get enable pr enable
if [ $enable != 1 ] ; then
	logger -t up-down-ffvpn "no policy routing freifunk-policyrouting.pr.enable=0"
	ip route add 0.0.0.0/1 via $route_net_gateway
	ip route add 128.0.0.0/1 via $route_net_gateway
	exit 0
fi

config_get strict pr strict
table="ffuplink"
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
		if [ -z "$gw" ]; then
			gw="$(echo $NETWORK|cut -d '.' -f -3)"".1"
		fi
		logger -t up-down-ffvpn "ugw: $ugw dev: $dev remote: $remote gw: $gw src: $src mask: $mask"
		ip route add "$net" dev "$dev" src "$src" table "$table"
		ip route add default via "$gw" dev "$dev" table "$table"
		ip route del 0.0.0.0/1 via "$gw" dev "$dev"
		ip route del 128.0.0.0/1 via "$gw" dev "$dev"
		ip rule list | grep -q "iif $dev lookup $table" || \
		ip rule add pref 20000 iif "$dev" lookup "$table"
		if [ "$strict" != 0 ]; then
			ip rule list | grep -q "iif $dev unreachable" || \
			ip rule add pref 20001 iif "$dev" unreachable
		fi
	fi
) >/tmp/ffvpn-up.log 2>&1 &

exit 0
