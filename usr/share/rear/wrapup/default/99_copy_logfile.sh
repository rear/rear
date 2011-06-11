#
# copy the logfile to the recovered system, at least the part that has been written till now.
#

if ! test -d /mnt/local/root ; then
	mkdir -p $v /mnt/local/root
	chmod $v 0700 /mnt/local/root
fi
AddExitTask "cat '$LOGFILE' >'/mnt/local/root/rear-$(date -Iseconds).log'"
