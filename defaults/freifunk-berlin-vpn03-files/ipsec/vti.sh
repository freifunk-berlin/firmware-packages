#!/bin/sh

# set "charon.install_virtual_ip = no" to prevent the daemon from also installing the VIP

set -o nounset
set -o errexit

VTI_IF="ffvpn"

case "${PLUTO_VERB}" in
    up-client)
        ip tunnel add "${VTI_IF}" local "${PLUTO_ME}" remote "${PLUTO_PEER}" mode vti \
            okey "${PLUTO_MARK_OUT%%/*}" ikey "${PLUTO_MARK_IN%%/*}"
        ip link set "${VTI_IF}" up
        ip addr add "${PLUTO_MY_SOURCEIP}" dev "${VTI_IF}"
        logger -t ipsec-vti "setting default-route for lan-clients via dev ${VTI_IF}"
        ip route add default dev "${VTI_IF}" table ff-client
        sysctl -w "net.ipv4.conf.${VTI_IF}.disable_policy=1"
        ;;
    down-client)
        ip tunnel del "${VTI_IF}"
        ;;
esac
