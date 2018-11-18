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
  # only disable interface on initial setup
  [ $curr="undefined" ] && uci set network.ffuplink.disabled=1
  uci commit network.ffuplink

  guard_delete notunnel
  guard_delete tunnelberlin_openvpn
  guard_delete tunnelberlin_tunneldigger
  guard_delete vpn03_openvpn
}
