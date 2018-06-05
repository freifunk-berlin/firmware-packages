#!/bin/sh
# This program will configure the mesh-interfaces
#

msg() {
	[ VERBOSE = "yes" ] && echo "$@"
}

setup_80211s() {
	
}


AUTOCOMMIT="no"
VERBOSE="no"

while getopts "ci:v" option; do
        case "$option" in
                c)
                        AUTOCOMMIT="yes"
                        ;;
                i)
                        INTERFACE="${OPTARG}"
                        ;;
                v)
                        VERBOSE="yes"
                        ;;
                *)
                        echo "Invalid argument '-$OPTARG'."
                        exit 1
                        ;;
        esac
done
shift $((OPTIND - 1))

case ${INTERFACE} in
	wireless2g)
		;;
	wireless5g)
		;;
	*)
		echo "unknown interface"
		exit 2
		;;
esac

