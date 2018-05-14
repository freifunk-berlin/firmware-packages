#!/bin/sh

. /lib/functions.sh

BBBDIGGER_SERV='77.87.51.51:8942'

# tunneldigger UUID (and MAC) generation, if there isn't one already
UUID=$(uci get tunneldigger.bbbdigger.uuid)
if [ $? -eq 1 ]; then
  UUID="b6"
  for byte in 2 3 4 5 6; do
    UUID=$UUID`dd if=/dev/urandom bs=1 count=1 2> /dev/null | hexdump -e '1/1 ":%02x"'`
  done

fi
echo $UUID

# remove all existing bbbdigger refences from the config files
uci delete tunneldigger.bbbdigger
uci delete network.bbbdigger
uci delete network.bbbdigger_dev
uci delete network.olsr_tunnel_bbbdigger_ipv4
uci delete network.olsr_default_bbbdigger_ipv4
uci delete network.olsr_default_unreachable_bbbdigger_ipv4
ZONE=$(uci show firewall.zone_freifunk.network | cut -d \' -f 2 | sed 's/ *bbbdigger *//g')
uci set firewall.zone_freifunk.network="${ZONE}"
uci delete $(uci show olsrd | grep bbbdigger | cut -d = -f 1)

#uci changes

# tunneldigger setup
uci set tunneldigger.bbbdigger=broker
uci add_list tunneldigger.bbbdigger.address=$BBBDIGGER_SERV
uci set tunneldigger.bbbdigger.uuid=$UUID
uci set tunneldigger.bbbdigger.interface=bbbvpn
uci set tunneldigger.bbbdigger.broker_selection=usage
uci set tunneldigger.bbbdigger.enabled=1

# network setup
uci set network.bbbdigger_dev=device
uci set network.bbbdigger_dev.macaddr=$UUID
uci set network.bbbdigger_dev.name=bbbdigger
uci set network.bbbdigger=interface
uci set network.bbbdigger.proto=dhcp
uci set network.bbbdigger.ifname=bbbdigger

uci set network.olsr_tunnel_bbbdigger_ipv4=rule
uci set network.olsr_tunnel_bbbdigger_ipv4.lookup=olsr-tunnel
uci set network.olsr_tunnel_bbbdigger_ipv4.priority=19999
uci set network.olsr_tunnel_bbbdigger_ipv4.in=bbbdigger

uci set network.olsr_default_bbbdigger_ipv4=rule
uci set network.olsr_default_bbbdigger_ipv4.lookup=olsr-default
uci set network.olsr_default_bbbdigger_ipv4.priority=20000
uci set network.olsr_default_bbbdigger_ipv4.in=bbbdigger

uci set network.olsr_default_unreachable_bbbdigger_ipv4=rule
uci set network.olsr_default_unreachable_bbbdigger_ipv4.action=unreachable
uci set network.olsr_default_unreachable_bbbdigger_ipv4.priority=20001
uci set network.olsr_default_unreachable_bbbdigger_ipv4.in=bbbdigger
 
# firewall setup
ZONE="$ZONE bbbdigger"
uci set firewall.zone_freifunk.network="${ZONE}"

# olsr setup
uci add olsrd Interface
uci set olsrd.@Interface[-1].ignore=0
uci set olsrd.@Interface[-1].interface=bbbdigger
uci set olsrd.@Interface[-1].Mode=ether

#uci changes

uci commit
