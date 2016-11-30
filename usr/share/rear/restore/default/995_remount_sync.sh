#
# At the end of the restoreonly WORKFLOW remount everything again with sync option
# so that the user can still do stuff but rebooting without umount is not so tragic any more
# cf. finalize/default/900_remount_sync.sh in the recover WORKFLOW
#
if test "restoreonly" = "$WORKFLOW" ; then
    while read mountpoint device mountby filesystem junk ; do
        if ! mount -o remount,sync "${device}" $TARGET_FS_ROOT"$mountpoint" ; then
            LogPrint "Remount sync of '${device}' failed. Do not reboot without umount."
            # Cf. /bin/reboot in the ReaR rescue/recovery system:
            LogPrint "syncing disks and waiting 3 seconds..."
            sync
            sleep 3
        fi
    done < "${VAR_DIR}/recovery/mountpoint_device"
fi

