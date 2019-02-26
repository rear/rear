#
# if the udev rules in the rescue system look different than in the original system then this is a sign
# that the hardware changed. Copy over the new udev rules, if they are different.

# do nothing if we don't have udev in the rescue system
have_udev || return 0

# we treat only these rules
RULE_FILES=( /etc/udev/rules.d/*persistent*{names,net,cd}.rules /etc/udev/rules.d/*eno-fix.rules )
# the result looks like this on various systems:
#   rear-centos4: ERROR
#   rear-debian5: /etc/udev/rules.d/70-persistent-cd.rules
#   rear-debian5: /etc/udev/rules.d/70-persistent-net.rules
#  rear-fedora11: /etc/udev/rules.d/70-persistent-cd.rules
#  rear-fedora11: /etc/udev/rules.d/70-persistent-net.rules
#       rear-osf: /etc/udev/rules.d/70-persistent-cd.rules
#       rear-osf: /etc/udev/rules.d/70-persistent-net.rules
#       rear-sl5: ERROR
#    rear-sles10: /etc/udev/rules.d/30-net_persistent_names.rules
#    rear-sles11: /etc/udev/rules.d/70-persistent-cd.rules
#    rear-sles11: /etc/udev/rules.d/70-persistent-net.rules
#     rear-sles9: ERROR

# for each rule file compare the version in the rescue system with the version in the restores backup
# and, if they differ, copy the version from the rescue system into the recovered system, of course
# preserving a backup in /root/rear-*.old
for rule in "${RULE_FILES[@]}" ; do
    rulefile="$( basename "$rule" )"
    # Skip if the one in the rescue system does not exists or is empty:
    test -s "$rule" || continue
    # Skip if the one in the rescue system is the same as the one from the restores backup:
    cmp -s "$rule" $TARGET_FS_ROOT/"$rule" && continue
    # Test for file $TARGET_FS_ROOT/$rule as BACKUP_RESTORE_MOVE_AWAY_FILES variable
    # may have prevented the restore of one of these files:
    test -f "$TARGET_FS_ROOT/$rule" && cp $v "$TARGET_FS_ROOT/$rule" $TARGET_FS_ROOT/root/rear-"$rulefile".old
    # Copy the rule from the rescue system to TARGET_FS_ROOT even if it did not exist in TARGET_FS_ROOT.
    # FIXME: It does not look right to test for $TARGET_FS_ROOT/$rule before making a backup in /root/rear-*.old
    # but to copy it from the rescue system into TARGET_FS_ROOT in any case even if it did not exist before
    # (why do we put files into the target system that were not restored from the backup?)
    # or when BACKUP_RESTORE_MOVE_AWAY_FILES has explicitly moved it away:
    LogPrint "Updating udev rule '$rulefile' with the one from the Relax-and-Recover rescue system"
    cp $v "$rule" "$TARGET_FS_ROOT/$rule" || LogPrintError "Failed to copy '$rule' to '$TARGET_FS_ROOT/$rule'"
done

