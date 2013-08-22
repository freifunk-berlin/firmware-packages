#!/bin/sh

logger -t up-down-ffvpn "dev: $1 mtu: $2 local: $4 remote: $5 init: $6"

table=$(uci -q get olsrd.@olsrd[0].RtTable)
#table=111
dev=$1
remote=$5

(
	sysctl -w net.ipv6.conf.$dev.disable_ipv6=1
	if [ -n "$table" ] ; then
		sleep 2
		gw=$(ip route show dev $dev | grep 0.0.0.0/1 | cut -d ' ' -f 3)
		logger -t up-down-ffvpn "sleep 2 dev: $dev remote: $remote gw: $gw"
		ip route del 0.0.0.0/1 via $gw dev $dev
		ip route del 128.0.0.0/1 via $gw dev $dev
		net=$(ip route show dev $dev | cut -d ' ' -f 1)
		src=$(ip route show dev $dev | cut -d ' ' -f 6)
		ip route add $net dev $dev src $src table $table
		ip route add default via $gw dev $dev table $table
		ip route del $net dev $dev
	fi
) >/tmp/ffvpn-up.log 2>&1 &

exit 0

