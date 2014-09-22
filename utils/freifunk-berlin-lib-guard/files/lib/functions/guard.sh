#!/bin/sh

# check if defaults have already been set
guard() {
  CFG="defaults"
  CFG_FILE="/etc/config/$CFG"
  SECTION="packages"
  NAME="default"
  OPTION=$1

  [ ! -f $CFG_FILE ] && touch $CFG_FILE && uci set $CFG.$NAME=$SECTION
  [ "$(uci get $CFG.$NAME.$OPTION)" == "1" ] && exit 0
  uci set $CFG.$NAME.$OPTION=1
  uci commit $CFG
}
