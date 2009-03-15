#
# copy the logfile to the recovered system, at least the part that has been written till now.
#

test -d /mnt/local/root || mkdir -p /mnt/local/root
trap "cat '$LOGFILE' >'/mnt/local/root/rear-$(date -Iseconds).log'" 0
