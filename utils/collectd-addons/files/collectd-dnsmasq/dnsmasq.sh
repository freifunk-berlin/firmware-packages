#!/bin/sh

logger "starting collectd dnsmasq"

#HOSTNAME=$(uci get system.@system[0].hostname)
HOSTNAME="${COLLECTD_HOSTNAME:-$(uci get system.\@system[0].hostname)}"

INTERVAL="${COLLECTD_INTERVAL:-60}"

LEASEFILE="$(uci get dhcp.@dnsmasq[0].leasefile)"
MAXLEASES="$(uci get dhcp.dhcp.limit)"

get_dhcplease_count() {
 cat ${LEASEFIlE} |wc -l
}


logger "entering loop"

while sleep 60; do
logger sending value
#while sleep "$INTERVAL"; do
#  VALUE=$(get_dhcplease_count)
  VALUE=$(cat ${LEASEFILE} | wc -l)
#  VALUE=$(cat /tmp/dhcp.leases |wc -l)
#echo 3
  echo "PUTVAL \"$HOSTNAME/exec-dnsmasq/gauge-dhcp-leases\" interval=$INTERVAL N:$VALUE"
  echo "PUTVAL \"$HOSTNAME/exec-dnsmasq/gauge-dhcp-range\" interval=$INTERVAL N:$MAXLEASES"
#logger "sending value: $VALUE"
#  echo "PUTVAL \"$HOSTNAME/exec-magic/gauge-magic_level\" interval=$INTERVAL N:5"
done

