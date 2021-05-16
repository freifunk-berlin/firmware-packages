#!/usr/bin/env sh

source /lib/functions.sh
source /lib/functions/semver.sh
source /etc/openwrt_release
source /lib/functions/guard.sh

# possible cases: 
# 1) firstboot with kathleen --> uci system.version not defined
# 2) upgrade from kathleen --> uci system.version defined
# 3) upgrade from non kathleen / legacy --> no uci system.version

OLD_VERSION=$(uci -q get system.@system[0].version)
# remove "special-version" e.g. "-alpha+3a7d"; only work on "basic" semver-strings
VERSION=${DISTRIB_RELEASE%%-*}

log() {
  logger -s -t freifunk-berlin-migration "$@"
  echo >>/root/migrate.log "$@"
}

if [ "Freifunk Berlin" = "${DISTRIB_ID}" ]; then
  log "Migration is running on a Freifunk Berlin system"
else
  log "no Freifunk Berlin system detected ..."
  exit 0
fi

# when upgrading from a pre-kathleen installation, there sould be
# at least on "very old file" in /etc/config ...
#
FOUND_OLD_FILE=false
# create helper to compare file ctime (1. Sep. 2014)
touch -d "201409010000" /tmp/timestamp
for testfile in /etc/config/*; do
  if [ "${testfile}" -ot /tmp/timestamp ]; then
    FOUND_OLD_FILE=true
    echo "guessing pre-kathleen firmware as of ${testfile}"
  fi
done
rm -f /tmp/timestamp

if [ -n "${OLD_VERSION}" ]; then
  # case 2)
  log "normal migration within Release ..."
elif [ ${FOUND_OLD_FILE} = true ]; then
  # case 3)
  log "migrating from legacy Freifunk Berlin system ..."
  OLD_VERSION='0.0.0'
else
  # case 1)
  log "fresh install - no migration"
  # add system.version with the new version
  log "Setting new system version to ${VERSION}; no migration needed."
  uci set system.@system[0].version=${VERSION}
  uci commit
  exit 0
fi

r1_1_0_change_olsrd_lib_num() {
  log "remove suffix from olsrd plugins"
  change_olsrd_lib_num_handle_config() {
    local config=$1
    local v6=$2
    local library=''
    local librarywo=''
    config_get library $config library
    librarywo=$(echo ${library%%.*})
    uci set olsrd$v6.$config.library=$librarywo
    log " changed olsrd$v6 $librarywo"
  }
  reset_cb
  config_load olsrd
  config_foreach change_olsrd_lib_num_handle_config LoadPlugin
  config_load olsrd6
  config_foreach change_olsrd_lib_num_handle_config LoadPlugin 6

}

r1_1_0_notunnel_ffuplink() {
  if [ "$(uci -q get ffberlin-uplink.preset.current)" == "no-tunnel" ]; then
    log "update the ffuplink_dev to have a static macaddr if not already set"
    local macaddr=$(uci -q get network.ffuplink_dev.macaddr)
    if [ $? -eq 1 ]; then
      # Create a static random macaddr for ffuplink device
      # start with fe for ffuplink devices
      # See the website https://www.itwissen.info/MAC-Adresse-MAC-address.html
      macaddr="fe"
      for byte in 2 3 4 5 6; do
        macaddr=$macaddr`dd if=/dev/urandom bs=1 count=1 2> /dev/null | hexdump -e '1/1 ":%02x"'`
      done
      uci set network.ffuplink_dev.macaddr=$macaddr
    fi
  fi
}

r1_1_0_notunnel_ffuplink_ipXtable() {
  if [ "$(uci -q get ffberlin-uplink.preset.current)" == "no-tunnel" ]; then
    log "update the ffuplink no-tunnel settings to use options ip4table and ip6table"
    uci set network.ffuplink.ip4table="ffuplink"
    uci set network.ffuplink.ip6table="ffuplink"
  fi
}

r1_1_0_olsrd_dygw_ping() {
  olsrd_dygw_ping() {
    local config=$1
    local lib=''
    config_get lib $config library
    local libname=${lib%%.*}
    if [ $lib == "olsrd_dyn_gw" ]; then
      uci del_list olsrd.$config.Ping=213.73.91.35   # dnscache.ccc.berlin.de
      uci add_list olsrd.$config.Ping=80.67.169.40   # www.fdn.fr/actions/dns
      uci del_list olsrd.$config.Ping=85.214.20.141  # old digitalcourage
      uci add_list olsrd.$config.Ping=46.182.19.48   # new digitalcourage
      return 1
    fi
  }
  reset_cb
  config_load olsrd
  config_foreach olsrd_dygw_ping LoadPlugin
}

r1_0_2_update_dns_entry() {
  log "updating DNS-servers for interface dhcp from profile"
  uci set network.dhcp.dns="$(uci get "profile_$(uci get freifunk.community.name).interface.dns")"
}

r1_0_2_add_olsrd_garbage_collection() {
  crontab -l | grep "rm -f /tmp/olsrd\*core"
  if [ $? == 1 ]; then
    log "adding garbage collection of core files from /tmp"
    echo "23 4 * * *	rm -f /tmp/olsrd*core" >> /etc/crontabs/root
    /etc/init.d/cron restart
  fi
}

r1_1_0_remove_olsrd_garbage_collection() {
  log "removing garbage collection of core files from /tmp"
  crontab -l | grep -v "rm -f /tmp/olsrd\*core" | crontab -
  /etc/init.d/cron restart
}

r1_1_0_update_dns_entry() {
  network_interface_delete_dns() {
    local config=${1}
    uci -q del network.${config}.dns
  }
  reset_cb
  config_load network
  config_foreach network_interface_delete_dns Interface
  uci set network.loopback.dns="$(uci get "profile_$(uci get freifunk.community.name).interface.dns")"
}

r1_1_0_update_uplink_notunnel_name() {
  log "update name of uplink-preset notunnel"
  local result=$(uci -q get ffberlin-uplink.preset.current)
  [[ $? -eq 0 ]] && [[ $result == "no-tunnel" ]] && uci set ffberlin-uplink.preset.current=notunnel
  result=$(uci -q get ffberlin-uplink.preset.previous)
  [[ $? -eq 0 ]] && [[ $result == "no-tunnel" ]] && uci set ffberlin-uplink.preset.previous=notunnel
  log "update name of uplink-preset notunnel done"
}

r1_1_0_firewall_remove_advanced() {
  firewall_remove_advanced() {
    uci -q delete firewall.$1
  }
  config_load firewall
  config_foreach firewall_remove_advanced advanced
}

migrate () {
  log "Migrating from ${OLD_VERSION} to ${VERSION}."

  # check for every migration task folder
  for scriptdir in /usr/share/freifunk-berlin-migration/*; do
    # only do mirgations for releases higher then the one we are come from
    if semverLT ${OLD_VERSION} "${scriptdir}"; then
      # run each script / task of the release-mirgation
      for script in /usr/share/freifunk-berlin-migration/${scriptdir}; do
        /bin/sh /usr/share/freifunk-berlin-migration/${scriptdir}/${script}
      done
    fi
  done

  # overwrite version with the new version
  log "Setting new system version to ${VERSION}."
  uci set system.@system[0].version=${VERSION}

  uci commit

  log "Migration done."
}

migrate
