#
# copy the logfile to the recovered system, at least the part that has been written till now.
#

if ! test -d /mnt/local/root ; then
	mkdir -p $v /mnt/local/root >&2
	chmod $v 0700 /mnt/local/root >&2
fi
AddExitTask "cat '$LOGFILE' >'/mnt/local/root/rear-$(date -Iseconds).log'"
