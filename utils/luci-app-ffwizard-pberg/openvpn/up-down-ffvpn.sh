#!/bin/sh

logger -t up-down-ffvpn "dev: $1 mtu: $2 local: $4 remote: $5 init: $6"

dev=$1
remote=$5

(
	if [ "`uci -q get olsrd.@olsrd[0].RtTable`" == "111" ] ; then
		sleep 5
		gw=$(ip route show dev $dev | grep 0.0.0.0/1 | cut -d ' ' -f 3)
		logger -t up-down-ffvpn "sleep 5 dev: $dev remote: $remote gw: $gw"
		sysctl -w net.ipv6.conf.$dev.disable_ipv6=1
		ip route add default via $gw dev $dev table 111
		ip route del 0.0.0.0/1 via $gw dev $dev
		ip route del 128.0.0.0/1 via $gw dev $dev
	fi
) &

exit 0

