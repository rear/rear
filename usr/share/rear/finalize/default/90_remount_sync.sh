#
# remount everything with sync option
#
# user can still do stuff but rebooting without umount is not so tragic any more.
#
while read mountpoint device mountby filesystem junk ; do
        mount -o remount,sync "${device}"  /mnt/local"$mountpoint"
        LogIfError "Remount sync of '${device}' failed"
done < "${VAR_DIR}/recovery/mountpoint_device"
