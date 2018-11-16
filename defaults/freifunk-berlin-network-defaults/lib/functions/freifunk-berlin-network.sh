#!/bin/sh

. /lib/functions/guard.sh

create_ffuplink() {
  uci -q delete network.ffuplink
  # create a very basic ffuplink interface
  uci set network.ffuplink=interface
  uci set network.ffuplink.ifname=ffuplink
  # see https://github.com/freifunk-berlin/firmware/issues/561
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
