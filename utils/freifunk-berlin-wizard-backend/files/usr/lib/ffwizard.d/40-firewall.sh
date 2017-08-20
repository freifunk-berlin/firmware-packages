#!/bin/sh

. /usr/share/libubox/jshn.sh

log_firewall() {
  logger -s -t ffwizard_firewall "$@"
}

setup_firewall() {
  # reset firewall config
  # note: "uci -q delete firewall" does not work
  uci import firewall <<EOF
EOF

  SECTION="$(uci add firewall defaults)"
  uci set firewall.$SECTION.syn_flood=1
  uci set firewall.$SECTION.input=ACCEPT
  uci set firewall.$SECTION.output=ACCEPT
  uci set firewall.$SECTION.forward=REJECT
  uci set firewall.$SECTION.drop_invalid=0

  ZONE="$(uci add firewall zone)"
  uci set firewall.$ZONE.name=wan
  uci set firewall.$ZONE.masq=1
  uci set firewall.$ZONE.network="wan wan6"
  uci set firewall.$ZONE.forward=REJECT
  uci set firewall.$ZONE.output=ACCEPT
  uci set firewall.$ZONE.local_restrict=1
  uci set firewall.$ZONE.input=ACCEPT

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Allow-DHCP-Renew
  uci set firewall.$RULE.src=wan
  uci set firewall.$RULE.proto=udp
  uci set firewall.$RULE.dest_port=68
  uci set firewall.$RULE.target=ACCEPT
  uci set firewall.$RULE.family=ipv4

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Allow-Ping
  uci set firewall.$RULE.src=wan
  uci set firewall.$RULE.proto=icmp
  uci set firewall.$RULE.icmp_type=echo-request
  uci set firewall.$RULE.family=ipv4
  uci set firewall.$RULE.target=ACCEPT

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Allow-DHCPv6
  uci set firewall.$RULE.src=wan
  uci set firewall.$RULE.proto=udp
  uci set firewall.$RULE.src_ip=fe80::/10
  uci set firewall.$RULE.src_port=547
  uci set firewall.$RULE.dest_ip=fe80::/10
  uci set firewall.$RULE.dest_port=546
  uci set firewall.$RULE.family=ipv6
  uci set firewall.$RULE.target=ACCEPT

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Allow-ICMPv6-Input
  uci set firewall.$RULE.src=wan
  uci set firewall.$RULE.proto=icmp
  uci set firewall.$RULE.icmp_type="echo-request echo-reply destination-unreachable packet-too-big time-exceeded bad-header unknown-header-type router-solicitation neighbour-solicitation router-advertisement neighbour-advertisement"
  uci set firewall.$RULE.limit=1000/sec
  uci set firewall.$RULE.family=ipv6
  uci set firewall.$RULE.target=ACCEPT

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Allow-ICMPv6-Forward
  uci set firewall.$RULE.src=wan
  uci set firewall.$RULE.dest=*
  uci set firewall.$RULE.proto=icmp
  uci set firewall.$RULE.icmp_type="echo-request echo-reply destination-unreachable packet-too-big time-exceeded bad-header unknown-header-type"
  uci set firewall.$RULE.limit=1000/sec
  uci set firewall.$RULE.family=ipv6
  uci set firewall.$RULE.target=ACCEPT

  INCLUDE="$(uci add firewall include)"
  uci set firewall.$INCLUDE.path=/etc/firewall.user

  # add named freifunk zone section
  uci set firewall.zone_freifunk=zone
  uci set firewall.zone_freifunk.input=ACCEPT
  uci set firewall.zone_freifunk.forward=REJECT
  uci set firewall.zone_freifunk.name=freifunk
  uci set firewall.zone_freifunk.output=ACCEPT

  networks="tunl0 dhcp internet_tunnel lan"
  # add wireless networks
  idx=0
  while uci -q get "wireless.radio${idx}" > /dev/null; do
    networks="${networks} wireless${idx}"
    idx=$((idx+1))
  done
  uci set firewall.zone_freifunk.network="${networks}"
  uci set firewall.zone_freifunk.device=tnl_+

  FORWARDING="$(uci add firewall forwarding)"
  uci set firewall.$FORWARDING.dest=freifunk
  uci set firewall.$FORWARDING.src=freifunk

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.proto=icmp
  uci set firewall.$RULE.target=ACCEPT
  uci set firewall.$RULE.src=freifunk

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.dest_port=80
  uci set firewall.$RULE.proto=tcp
  uci set firewall.$RULE.target=ACCEPT
  uci set firewall.$RULE.src=freifunk

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.dest_port=443
  uci set firewall.$RULE.proto=tcp
  uci set firewall.$RULE.target=ACCEPT
  uci set firewall.$RULE.src=freifunk

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.dest_port=22
  uci set firewall.$RULE.proto=tcp
  uci set firewall.$RULE.target=ACCEPT
  uci set firewall.$RULE.src=freifunk

  ADVANCED="$(uci add firewall advanced)"
  uci set firewall.$ADVANCED.tcp_westwood=1
  uci set firewall.$ADVANCED.tcp_ecn=0
  uci set firewall.$ADVANCED.ip_conntrack_max=8192

  FORWARDING="$(uci add firewall forwarding)"
  uci set firewall.$FORWARDING.dest=wan
  uci set firewall.$FORWARDING.src=freifunk

  FORWARDING="$(uci add firewall forwarding)"
  uci set firewall.$FORWARDING.dest=freifunk
  uci set firewall.$FORWARDING.src=wan

  # prevent traffic from freifunk to private networks via wan
  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Disallow-wan-v4-private-a
  uci set firewall.$RULE.src=freifunk
  uci set firewall.$RULE.dest=wan
  uci set firewall.$RULE.family=ipv4
  uci set firewall.$RULE.dest_ip="10.0.0.0/8"
  uci set firewall.$RULE.target=REJECT
  uci set firewall.$RULE.proto=all

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Disallow-wan-v4-private-b
  uci set firewall.$RULE.src=freifunk
  uci set firewall.$RULE.dest=wan
  uci set firewall.$RULE.family=ipv4
  uci set firewall.$RULE.dest_ip="172.16.0.0/12"
  uci set firewall.$RULE.target=REJECT
  uci set firewall.$RULE.proto=all

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Disallow-wan-v4-private-c
  uci set firewall.$RULE.src=freifunk
  uci set firewall.$RULE.dest=wan
  uci set firewall.$RULE.family=ipv4
  uci set firewall.$RULE.dest_ip="192.168.0.0/16"
  uci set firewall.$RULE.target=REJECT
  uci set firewall.$RULE.proto=all

  RULE="$(uci add firewall rule)"
  uci set firewall.$RULE.name=Disallow-wan-v6-ula
  uci set firewall.$RULE.src=freifunk
  uci set firewall.$RULE.dest=wan
  uci set firewall.$RULE.family=ipv6
  uci set firewall.$RULE.dest_ip="fd00::/8"
  uci set firewall.$RULE.target=REJECT
  uci set firewall.$RULE.proto=all

  uci commit firewall

}

setup_firewall
