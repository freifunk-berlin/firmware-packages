#!/bin/sh

. /lib/functions.sh

# clear out all bbbdigger settings

# tunneldigger
uci del tunneldigger.bbbdigger

# network
uci del network.interface.bbbdigger
uci del network.device.bbbdigger
# create bbbdigger setup

# tunneldigger
uci set tunneldigger.bbbdigger=broker
uci set tunneldigger.bbbdigger.enabled=1
uci add_list tunneldigger.bbbdigger.address='77.87.51.51:8942'
uci set tunneldigger.bbbdigger.uuid=$UUID
uci set tunneldigger.bbbdigger.interface=bbbvpn
uci set tunneldigger.bbbdigger.broker_selection=usage

