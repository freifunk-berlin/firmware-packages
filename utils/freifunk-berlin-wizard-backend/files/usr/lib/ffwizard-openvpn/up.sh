#!/bin/sh

name=$1

log_openvpn() {
  logger -s -t openvpn-up "$@"
}

(
  log_openvpn "setting routes for tunnel $@"

  table=ff-${name}-tunnel
  dev=${name}_tunnel

  # make sure we can still reach the vpn server
  if [ ! -z "$route_net_gateway" ] && [ ! -z "$trusted_ip" ]; then
    ip route add "${trusted_ip}/32" via $route_net_gateway
  fi

  if [ ! -z "$ifconfig_local" ] && [ ! -z "$ifconfig_netmask" ]; then
    eval $(ipcalc.sh "$ifconfig_local" "$ifconfig_netmask")
    net="$NETWORK/$PREFIX"

    ip route add "$net" dev "$dev" src "$ifconfig_local" table "$table"
  fi

  if [ ! -z "$route_vpn_gateway" ]; then
    ip route add default via "$route_vpn_gateway" dev "$dev" table "$table"
  fi
) > /tmp/ffvpn-up.log 2>&1 &
