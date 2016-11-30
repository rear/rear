#
# For the restoreonly WORKFLOW remount everything without sync option
# otherwise the restore would be terribly slow.
# Things may have been remounted with sync option in a preceding recover WORKFLOW
# via finalize/default/900_remount_sync.sh
#
if test "restoreonly" = "$WORKFLOW" ; then
    while read mountpoint device mountby filesystem junk ; do
        if ! mount -o remount,async "${device}" $TARGET_FS_ROOT"$mountpoint" ; then
            LogPrint "Remount async of '${device}' failed which can result very slow restore"
        fi
    done < "${VAR_DIR}/recovery/mountpoint_device"
fi

