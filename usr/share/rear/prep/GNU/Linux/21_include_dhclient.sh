# copy the binaries and config files that we require to use dhclient
# on the rescue image
[ -z "USE_DHCLIENT" ] && return	# empty string means no dhcp client support required

REQUIRED_PROGS=(
"${REQUIRED_PROGS[@]}"
dhclient
)

# we made our own /etc/dhclient.conf and /bin/dhclient-script files (no need to copy these
# from the local Linux system)
COPY_AS_IS=( "${COPY_AS_IS[@]}" "/etc/localtime" )
PROGS=( "${PROGS[@]}" arping mktemp ipcalc seq usleep env )

