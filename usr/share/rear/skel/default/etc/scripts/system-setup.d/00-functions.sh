# helper functions
# call udevtrigger
my_udevtrigger() {
        type -p udevadm >/dev/null && udevadm trigger $@ || udevtrigger $@
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
