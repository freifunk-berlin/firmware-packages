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

update_crontab_memory_leak_fix() {
  # Hotfix for collectd memory leak: restart luci_statistics every 30 minutes
  # see https://github.com/freifunk-berlin/firmware/issues/217
  CRONTAB="/etc/crontabs/root"
  CMD="/etc/init.d/luci_statistics"
  test -f $CRONTAB || touch $CRONTAB
  grep -q $CMD $CRONTAB || echo "0,30 * * * *    $CMD" >> $CRONTAB
  /etc/init.d/cron restart
}

update_olsr_smart_gateway_threshold() {
  # set SmartGatewayThreshold if not set
  local threshold=$(uci get olsrd.olsrd.SmartGatewayThreshold)
  if [ "x${threshold}" = x ]; then
    log "Setting SmartGatewayThreshold to 50."
    uci set olsrd.olsrd.SmartGatewayThreshold='50'
  fi
}

migrate () {
  log "Migrating from ${OLD_VERSION} to ${VERSION}."

  if semverLT ${OLD_VERSION} "0.1.0"; then
    update_openvpn_remote_config
    update_dhcp_lease_config
    update_wireless_ht20_config
    update_luci_statistics_config
    update_crontab_memory_leak_fix
    update_olsr_smart_gateway_threshold
  fi

  # overwrite version with the new version
  log "Setting new system version to ${VERSION}."
  uci set system.@system[0].version=${VERSION}

  uci commit

  log "Migration done."
}

migrate
