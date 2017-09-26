# helper functions
# call udevtrigger
my_udevtrigger() {
    type -p udevadm >/dev/null && udevadm trigger $@ || udevtrigger $@

    # If systemd is running, this should help to rename devices
    if [[ $(ps --no-headers -C systemd) ]]; then
        sleep 1
        my_udevsettle
        udevadm trigger --action=add
    fi
}

# call udevsettle
my_udevsettle() {
    type -p udevadm >/dev/null && udevadm settle --timeout=10 $@ || udevsettle $@
}

# call udevinfo
my_udevinfo() {
        type -p udevadm >/dev/null && udevadm info "$@" || udevinfo "$@"
}

Error() {
	echo "ERROR: $*"
}


# source the global functions
. /usr/share/rear/lib/global-functions.sh

# source the network functions
. /usr/share/rear/lib/network-functions.sh
