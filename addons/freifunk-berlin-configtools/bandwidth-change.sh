#!/bin/sh
# This program should change bandwidth settings on freifunk routers
# Copyright (C) 2018 holger@freifunk-berlin
# inspired by depricated https://github.com/freifunk-berlin/firmware-packages/commit/3a923a89e705da88bd44bb78d4ebfa6655b3960e
#

# display current settings:
show_settings() {
  echo 'current settings'
  usersBandwidthDown=$(uci get ffwizard.settings.usersBandwidthDown)
  usersBandwidthUp=$(uci get ffwizard.settings.usersBandwidthUp)
  echo " userdown $(( $usersBandwidthDown * 1000))"
  echo " userup   $(( $usersBandwidthUp * 1000))"
  echo " qosdown  $(uci get qos.ffuplink.download)"
  echo " qosup    $(uci get qos.ffuplink.upload)"
}

AUTOCOMMIT="no"
OPERATION="show"

while getopts "cd:u:" option; do
        case "$option" in
                d)
                        DOWNSPEED="${OPTARG}"
                        OPERATION="set"
                        ;;
                u)
                        UPSPEED="${OPTARG}"
                        OPERATION="set"
                        ;;
                c)
                        AUTOCOMMIT="yes"
                        ;;
                *)
                        echo "Invalid argument '-$OPTARG'."
                        exit 1
                        ;;    
        esac              
done        
shift $((OPTIND - 1))

#if [ ${OPERATION} == "set" ]; then
#		[ -z ${DOWNSPEED} ] && echo "value missing for desiredqosdown" && exit 1; 
#		[ -z ${UPSPEED} ] && echo "value missing for desiredqosup" && exit 1;
#fi

# should this script run?
if [ "$(uci get ffwizard.settings.sharenet 2> /dev/null)" == "0" ]; then
    echo 'dont share my internet' && exit 0
	elif [ "$(uci get ffwizard.settings.sharenet 2> /dev/null)" == "1" ]; then
    		echo 'share my internet'
	else
		echo 'sharenet value unknown' && exit 1
fi
# can we change olsrd file?
if [ -e /etc/config/olsrd ]; then
		echo 'file olsrd found' 
	else 
		echo 'file olsrd not found' && exit 1
fi

show_settings

desiredqosdown=${DOWNSPEED}
desiredqosup=${UPSPEED}

echo desiredqosdown $desiredqosdown
echo desiredqosup $desiredqosup
# change olsrd-settings
if [ ${OPERATION} == "set" ]; then
	uci set olsrd.@olsrd[0].SmartGatewaySpeed="${desiredqosup} ${desiredqosdown}";
	uci set qos.ffuplink.download=$desiredqosdown;
	uci set qos.ffuplink.upload=$desiredqosup;
	usersBandwidthDown=$(($desiredqosdown / 1000));
	uci set ffwizard.settings.usersBandwidthDown=$usersBandwidthDown;
	usersBandwidthUp=$(($desiredqosup / 1000));
	uci set ffwizard.settings.usersBandwidthUp=$usersBandwidthUp
fi
# shall I commit changes? Yes, when called by hand.
if [ ${AUTOCOMMIT} == "yes" ];  then
	echo 'uci commit qos';
	uci commit olsrd;
	uci commit qos.ffuplink;
	uci commit ffwizard.settings;
	reload_config
else 
	echo 'uci dont commit qos'
	
fi


exit 0
