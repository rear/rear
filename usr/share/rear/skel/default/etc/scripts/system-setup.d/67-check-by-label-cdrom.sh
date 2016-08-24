# On Ubuntu we have received many reports of a missing /dev/disk/by-label/RELAXRECOVER link
# and therefore during recovery the cdrom was not found automatically - details are in #326

# check if the symbolic link exist? Yes - just return
[[ -h /dev/disk/by-label/RELAXRECOVER ]] && return

if [[ -h /dev/cdrom ]] ; then
    ln -s  /dev/cdrom /dev/disk/by-label/RELAXRECOVER
elif [[ -b /dev/sr0 ]] ; then
    ln -s /dev/sr0 /dev/disk/by-label/RELAXRECOVER
else
    echo "Did not find a cdrom device. Recover might fail."
fi
