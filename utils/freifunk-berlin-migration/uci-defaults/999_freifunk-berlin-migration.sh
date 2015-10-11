#!/usr/bin/env sh

source /lib/functions/semver.sh

OLD_VERSION=$(uci get system.@system[0].version)
OLD_VERSION=${OLD_VERSION:-'0.0.0'}
VERSION=$(cat /etc/openwrt_version)

log() {
  logger -s -t freifunk-berlin-migration $@
}

update_openvpn_remote_config() {
  # use dns instead of ips for vpn servers (introduced with 0.1.0)
  log "Setting openvpn.ffvpn.remote to vpn03.berlin.freifunk.net"
  uci delete openvpn.ffvpn.remote
  uci add_list openvpn.ffvpn.remote='vpn03.berlin.freifunk.net 1194 udp'
  uci add_list openvpn.ffvpn.remote='vpn03-backup.berlin.freifunk.net 1194 udp'
}

update_dhcp_lease_config() {
  # set lease time to 5 minutes (introduced with 0.1.0)
  local current_leasetime=$(uci get dhcp.dhcp.leasetime)
  if [ "x${current_leasetime}" = "x" ]; then
    log "Setting dhcp lease time to 5m"
    uci set dhcp.dhcp.leasetime='5m'
  fi
}

update_wireless_ht20_config() {
  # set htmode to ht20 (introduced with 0.1.0)
  log "Setting htmode to HT20 for radio0"
  uci set wireless.radio0.htmode='HT20'
  local radio1_present=$(uci get wireless.radio1.htmode)
  # set htmode if radio1 is present
  if [ "x${radio1_present}" != x ]; then
    log "Setting htmode to HT20 for radio1."
    uci set wireless.radio1.htmode='HT20'
  fi
}

update_luci_statistics_config() {
  # if users disabled stats with the wizard some settings need be corrected
  # so they can enable stats later
  log "remove luci_statistics.rrdtool.enable"
  log "remove luci_statistics.collectd.enable"
  uci delete luci_statistics.rrdtool.enable
  uci delete luci_statistics.collectd.enable

  # enable luci_statistics service
  log "enable luci_statistics service"
  /etc/init.d/luci_statistics enable
}

update_collectd_memory_leak_hotfix() {
  # Remove old hotfixes for collectd RAM issues on 32MB routers
  # see https://github.com/freifunk-berlin/firmware/issues/217
  CRONTAB="/etc/crontabs/root"
  test -f $CRONTAB || touch $CRONTAB
  sed -i '/luci_statistics$/d' $CRONTAB
  sed -i '/luci_statistics restart$/d' $CRONTAB
  /etc/init.d/cron restart

  if [ "$(cat /proc/meminfo |grep MemTotal:|awk {'print $2'})" -lt "65536" ]; then
    uci set luci_statistics.collectd_ping.enable=0
    uci set luci_statistics.collectd_rrdtool.enable=0
  fi
}

update_olsr_smart_gateway_threshold() {
  # set SmartGatewayThreshold if not set
  local threshold=$(uci get olsrd.@olsrd[0].SmartGatewayThreshold)
  if [ "x${threshold}" = x ]; then
    log "Setting SmartGatewayThreshold to 50."
    uci set olsrd.@olsrd[0].SmartGatewayThreshold='50'
  fi
}

fix_olsrd_txtinfo_port() {
  uci set $(uci show olsrd|grep olsrd_txtinfo|cut -d '=' -f 1|sed 's/library/port/')=2006
  uci set $(uci show olsrd6|grep olsrd_txtinfo|cut -d '=' -f 1|sed 's/library/port/')=2006
}

add_openvpn_mssfix() {
  uci set openvpn.ffvpn.mssfix=1300
}

openvpn_ffvpn_hotplug() {
  uci set openvpn.ffvpn.up="/lib/freifunk/ffvpn-up.sh"
  uci set openvpn.ffvpn.enabled=0
  /etc/init.d/openvpn disable
  for entry in `uci show firewall|grep Reject-VPN-over-ff|cut -d '=' -f 1`; do
    uci delete ${entry%.name}
  done
  for entry in `uci show freifunk-watchdog|grep process=openvpn|cut -d '=' -f 1`; do
    uci delete ${entry%.process}
  done
}

update_collectd_ping() {
 uci set luci_statistics.collectd_ping.Interval=10
 uci set luci_statistics.collectd_ping.Hosts=ping.berlin.freifunk.net
}

fix_qos_interface() {
  for rule in `uci show qos|grep qos.wan`; do
    uci set ${rule/wan/ffvpn}
  done
  uci delete qos.wan

sgw_rules_to_fw3() {
  uci set firewall.zone_freifunk.device=tnl_+
  sed -i '/iptables -I FORWARD -o tnl_+ -j ACCEPT$/d' /etc/firewall.user
}

migrate () {
  log "Migrating from ${OLD_VERSION} to ${VERSION}."

  if semverLT ${OLD_VERSION} "0.1.0"; then
    update_openvpn_remote_config
    update_dhcp_lease_config
    update_wireless_ht20_config
    update_luci_statistics_config
    update_olsr_smart_gateway_threshold
  fi

  if semverLT ${OLD_VERSION} "0.1.1"; then
    update_collectd_memory_leak_hotfix
    fix_olsrd_txtinfo_port
  fi

  if semverLT ${OLD_VERSION} "0.1.2"; then
    add_openvpn_mssfix
  fi

  if semverLT ${OLD_VERSION} "0.2.0"; then
    update_collectd_ping
    fix_qos_interface
    openvpn_ffvpn_hotplug
    sgw_rules_to_fw3
  fi

  # overwrite version with the new version
  log "Setting new system version to ${VERSION}."
  uci set system.@system[0].version=${VERSION}

  uci commit

  log "Migration done."

  # delete any overlay config files duplicated from romfs by sysupgrade - saves JFFS2 space
  cd /overlay/upper/etc/config/ && for i in *; do [ -f "$i" ] && if cmp -s "$i" "/rom/etc/config/$i"; then rm -f "$i"; fi; done;
}

migrate
