#!/bin/sh

. /usr/share/libubox/jshn.sh

log_system() {
	logger -s -t ffwizard_system "$@"
}

setup_system() {
	local cfg=$1
	json_init
	json_load "$CONFIG_JSON" || exit 1
	json_select config

	json_select router

	# password
	# TODO: use a passwordHash that is generated in the frontend
	local password
	if json_get_var password password; then
		(echo "$password"; sleep 1; echo "$password") | passwd
		log_system "Password updated."
	fi

	# hostname
	local hostname
	local rand
	if json_get_var hostname name; then
		uci -q set "system.@system[-1].hostname=$hostname"
	else
		rand="$(echo -n $(head -n 1 /dev/urandom 2>/dev/null | md5sum | cut -b 1-4))"
		hostname="freifunk-$rand"
		log_system "No valid Hostname! Set rand Hostname $hostname"
		uci -q set "system.@system[-1].hostname=$hostname"
	fi

	json_select ..
	json_select location

	# Set Timezone
	uci -q set 'system.@system[-1].zonename="Europe/Berlin'
	uci -q set 'system.@system[-1].timezone="CET-1CEST,M3.5.0,M10.5.0/3"'

	# Set Location
	local location=""
	if json_get_var street street ; then location="$location $street" ; fi
	if json_get_var postalCode postalCode; then location="$location, $postalCode" ; fi
	if json_get_var city city; then location="$location, $city" ; fi
	if [ -n "$location" ] ; then
		uci -q set "system.@system[-1].location=$location"
	fi

	# Set Geo Location
	local latitude
	if json_get_var lat latitude; then
		uci -q set "system.@system[-1].latitude=$latitude"
	fi

	local longitude
	if json_get_var lng longitude; then
		uci -q set "system.@system[-1].longitude=$longitude"
	fi

	uci commit system
}

setup_system
