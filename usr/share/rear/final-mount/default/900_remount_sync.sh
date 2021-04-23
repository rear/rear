#
# At the end of the recover WORKFLOW
# remount all what is mounted below /mnt/local with sync option.
#
# User can still do stuff after "rear recover" had finished
# but rebooting without umount is not so tragic any more.
# On the other hand remounting with sync option could become
# in practice a major annoyance because it makes writing
# anything below /mnt/local basically unusable slow,
# see https://github.com/rear/rear/issues/1097
#
# Remounting with sync option is no longer needed when systemd is used because
# when systemd is used reboot, halt, poweroff, and shutdown are replaced by
# scripts that do umount plus sync to safely shut down the recovery system,
# cf. https://github.com/rear/rear/pull/1011

# Skip if not 'recover' or 'mountonly' WORKFLOW:
test "recover" = "$WORKFLOW" -o "mountonly" = "$WORKFLOW" || return 0

# Skip if systemd is used
# systemctl gets copied into the recovery system as /bin/systemctl:
test -x /bin/systemctl && return 0

# Remount with sync option of all what is mounted below /mnt/local:
while read mountpoint device mountby filesystem junk ; do
        mount -o remount,sync "${device}" $TARGET_FS_ROOT"$mountpoint"
        LogIfError "Remount sync of '${device}' failed"
done < "${VAR_DIR}/recovery/mountpoint_device"

