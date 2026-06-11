#
# For the restoreonly WORKFLOW remount everything without sync option
# otherwise the restore would be terribly slow.
# Things may have been remounted with sync option in a preceding recover WORKFLOW
# via finalize/default/900_remount_sync.sh
# see also https://github.com/rear/rear/issues/1097
#
# Remounting with async option is not needed when systemd is used because
# when systemd is used remounting with sync option is skipped in a preceding
# recover WORKFLOW via finalize/default/900_remount_sync.sh and to avoid
# needless operations remounting with async option is also skipped here
# cf. https://github.com/rear/rear/issues/1097

# Skip if not restoreonly WORKFLOW:
test "restoreonly" = "$WORKFLOW" || return 0

# Skip if systemd is used
# systemctl gets copied into the recovery system as /bin/systemctl:
test -x /bin/systemctl && return 0

while read mountpoint device mountby filesystem junk ; do
    if ! mount -o remount,async "${device}" $TARGET_FS_ROOT"$mountpoint" ; then
        LogPrint "Remount async of '${device}' failed which can result very slow restore"
    fi
done < "${VAR_DIR}/recovery/mountpoint_device"

