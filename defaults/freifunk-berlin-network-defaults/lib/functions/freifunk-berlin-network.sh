#!/bin/sh

. /lib/functions/guard.sh

create_ffuplink() {
  curr=$(uci get ffberlin-uplink.preset.current)
#  prev=$(uci get ffberlin-uplink.preset.previous)

  uci -q delete network.ffuplink
  # create a very basic ffuplink interface
  uci set network.ffuplink=interface
  uci set network.ffuplink.ifname=ffuplink
  uci set network.ffuplink.ip4table=ffuplink
  uci set network.ffuplink.ip6table=ffuplink
  # the following options need to be set by the individual uplink-package
  uci set network.ffuplink.proto=none
  uci commit network.ffuplink

  guard_delete notunnel
  guard_delete tunnelberlin_openvpn
  guard_delete tunnelberlin_tunneldigger
  guard_delete vpn03_openvpn
}

ffuplink_disable() {
  local section=$(uci -q get ffberlin_uplink.ffuplink.disable_section)
  local field=$(uci -q get ffberlin-uplink.ffuplink.disable_field)
  local value=$(uci -q get ffberlin-uplink.ffuplnik.disable_value)

  if [[ ! -z $section ]]; then
    uci set ${section}.${field}=$value
    uci -q delete ffberlin-uplink.ffuplink.disable_section
    uci -q delete ffberlin-uplink.ffuplink.disable_field
    uci -q delete ffberlin-uplink.ffuplink.disable_value
    uci commit $section
  fi
}
