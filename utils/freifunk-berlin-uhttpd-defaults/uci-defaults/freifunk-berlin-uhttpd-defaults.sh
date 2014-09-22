#!/bin/sh

# check if defaults have already been set
CFG="default"
CFG_FILE="/etc/config/$CFG"
SECTION="packages"
NAME="default"
OPTION="uhttpd"

# insert a random part into commonname (Freifunk Berlin - <random>)
# this should help us to avoid different certificates with same
# commonname/issuer id
uci set uhttpd.px5g.commonname="Freifunk Berlin - $(dd if=/dev/urandom bs=4 count=1 | hexdump -e '1/1 "%02x"')"
uci commit
