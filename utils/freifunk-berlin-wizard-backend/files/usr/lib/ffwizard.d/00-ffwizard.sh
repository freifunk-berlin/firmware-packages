#!/bin/sh

log_ffwizard() {
	logger -s -t ffwizard_ffwizard "$@"
}


setup_ffwizard() {
  touch /etc/config/ffwizard
  uci add ffwizard ffwizard > /dev/null

  local lan_ifname=$(uci -q get "ffwizard.@ffwizard[-1].lan_ifname")
  if [ -z "$lan_ifname" ]; then
    lan_ifname=$(uci get network.lan.ifname)
    uci set "ffwizard.@ffwizard[-1].lan_ifname=$lan_ifname"
  fi
  if [ -z "$lan_ifname" ]; then
    log_ffwizard "could not get lan ifname"
    exit 1
  fi

  local lan_macaddr=$(uci -q get "ffwizard.@ffwizard[-1].lan_macaddr")
  if [ -z "$lan_macaddr" ]; then
    lan_macaddr=$(uci -q get network.lan.macaddr)
    uci set "ffwizard.@ffwizard[-1].lan_macaddr=$lan_macaddr"
  fi

  uci commit ffwizard
}

setup_ffwizard
