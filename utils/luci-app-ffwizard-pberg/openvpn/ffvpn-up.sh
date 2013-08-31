#!/bin/sh

table=$(uci -q get olsrd.@olsrd[0].RtTableDefault)
dev="$1"
remote="$5"

(
	sysctl -w net.ipv6.conf.$dev.disable_ipv6=1
	if [ -n "$table" ] ; then
		sleep 2
		ugw="$route_net_gateway"
		gw="$route_vpn_gateway"
		src="$ifconfig_local"
		mask="$ifconfig_netmask"
		eval $(ipcalc.sh $src $mask)
		net="$NETWORK/$PREFIX"
		logger -t up-down-ffvpn "ugw: $ugw dev: $dev remote: $remote gw: $gw src: $src mask: $mask table: $table"
		ip route add $net dev $dev src $src table $table
		ip route add $remote_1 via $ugw table main
		ip route add default via $ugw table default
		ip route del 0.0.0.0/1 via $gw dev $dev
		ip route del 128.0.0.0/1 via $gw dev $dev
		ip route add default via $gw dev $dev table $table metric 10
		ip rule add pref 20000 iif $dev lookup $table
		ip rule add pref 20001 iif $dev unreachable
	fi
) >/tmp/ffvpn-up.log 2>&1 &

exit 0
