#
# Galaxy checks for free disk space in /opt /var and /tmp
#
# Our initramfs doesn't report any free disk space, so that we have to setup
# a tmpfs for that
#
mkdir /ramdisk
mount -o size=700m -t tmpfs none /ramdisk

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
