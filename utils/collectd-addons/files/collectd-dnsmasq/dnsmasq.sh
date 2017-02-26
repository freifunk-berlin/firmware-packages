#!/bin/sh

logger -t collectd-dnsmasq-addon "started"

HOSTNAME="${COLLECTD_HOSTNAME:-$(uci get system.\@system[0].hostname)}"
INTERVAL="${COLLECTD_INTERVAL:-60}"

LEASEFILE="$(uci get dhcp.@dnsmasq[0].leasefile)"
MAXLEASES="$(uci get dhcp.dhcp.limit)"

while sleep 60; do
  VALUE=$(cat ${LEASEFILE} | wc -l)
  echo "PUTVAL \"$HOSTNAME/exec-dnsmasq/gauge-dhcp-leases\" interval=$INTERVAL N:$VALUE"
  echo "PUTVAL \"$HOSTNAME/exec-dnsmasq/gauge-dhcp-range\" interval=$INTERVAL N:$MAXLEASES"
done
