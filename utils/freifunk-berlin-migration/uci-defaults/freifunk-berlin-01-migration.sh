#!/usr/bin/env sh

source /lib/functions.sh
source /lib/functions/semver.sh
source /etc/openwrt_release
source /lib/functions/guard.sh

if [ $( uci -q get system.@system[0].was_development) = "1" ]; then
  echo "Non released code was ran on system. skipping migration ..."
  exit 0
fi

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

run_migrationsteps() {
    VERSION = $1

    [ -z ${VERSION} ] && (log "migration: no version provided"; exit 1)
    # run each script / task of the release-mirgation
    for script in /usr/share/freifunk-berlin-migration/${VERSION}; do
      /bin/sh /usr/share/freifunk-berlin-migration/${VERSION}/${script}
    done
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

log "Migrating from ${OLD_VERSION} to ${VERSION}."

# check for every migration task folder
for scriptdir in /usr/share/freifunk-berlin-migration/*; do
  # only do mirgations for releases higher then the one we are come from
  if semverLT ${OLD_VERSION} "${scriptdir}"; then
    run_migrationsteps "${scriptdir}"
  fi
done

# overwrite version with the new version
log "Setting new system version to ${VERSION}."
uci set system.@system[0].version=${VERSION}

uci commit

log "Migration done."
