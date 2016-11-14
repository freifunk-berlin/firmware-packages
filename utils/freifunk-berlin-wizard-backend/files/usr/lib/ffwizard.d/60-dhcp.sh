#!/bin/sh

. /usr/share/libubox/jshn.sh

log_dhcp() {
	logger -s -t ffwizard_dhcp "$@"
}

setup_dhcp() {
	local cfg=$1
	json_init
	json_load "$CONFIG_JSON" || exit 1
	json_select config

	json_select ip

  # ignore lan interface
  uci -q delete "dhcp.lan"
  uci set "dhcp.lan=dhcp"
  uci set "dhcp.lan.interface=lan"
  uci set "dhcp.lan.ignore=1"

  # dhcp interface
  uci -q delete "dhcp.dhcp"
  uci set "dhcp.dhcp=dhcp"
  uci set "dhcp.dhcp.interface=dhcp"

  local distribute;
  json_get_var distribute distribute
  if [ "$distribute" == "1" ]; then
    uci set "dhcp.dhcp.dhcpv6=server"
    uci set "dhcp.dhcp.ra=server"
    uci set "dhcp.dhcp.leasetime=5m"
    uci set "dhcp.dhcp.start=0"
    uci set "dhcp.dhcp.limit=1022"
    uci add_list "dhcp.dhcp.dhcp_option=119,olsr"
  else
    uci set "dhcp.dhcp.ignore=1"
  fi

  uci commit dhcp
}

setup_dhcp
