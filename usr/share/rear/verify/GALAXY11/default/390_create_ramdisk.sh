#
# Commvault checks for free disk space in /opt /var and /tmp
#
# Our initramfs doesn't report any free disk space, so that we have to setup
# a tmpfs for that. 1500MB ist just a guess, if your system blows because of this
# you should feel free to determine a better way or a smaller ramdisk size to suffice
# (be warned, lots of tests are required for this ...)
#

# we want to do this only once ...
if test -d /ramdisk || return 0

mkdir /ramdisk
mount -o size=1500m -t tmpfs none /ramdisk

# stop logfile
exec 2>&1

pushd / >/dev/null
for dir in opt var tmp ; do
	mv "$dir" /ramdisk
	mkdir "$dir"
	mount --bind /ramdisk/"$dir" /"$dir"
done
chmod 1777 /tmp
popd >/dev/null


# start logfile
exec 2>>"$RUNTIME_LOGFILE"
