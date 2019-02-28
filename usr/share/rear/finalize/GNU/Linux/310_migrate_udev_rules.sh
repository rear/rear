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
# SLES12-SP4 and openSUSE Leap 15.0: /etc/udev/rules.d/70-persistent-net.rules

# For each rule file compare the version in the rescue system with the version in the restored backup
# and, if they differ, copy the version from the rescue system into the recovered system, of course
# preserving a backup in /root/rear-*.old
for rule in "${RULE_FILES[@]}" ; do
    # Skip if there was no such udev rule file restored from the backup
    # because we must not put files into the recreated system that have not been there
    # in particular no udev rule files because wrong udev rules can cause severe issues.
    # E.g. nowadays /etc/udev/rules.d/70-persistent-net.rules is created and maintained
    # by systemd/udev (see https://github.com/rear/rear/issues/770) so that we must not
    # mess around with systemd/udev by creating udev rules in the recreated system:
    test -f "$TARGET_FS_ROOT/$rule" || continue
    # Skip if the one in the rescue system does not exists or is empty:
    test -s "$rule" || continue
    # Skip if the one in the rescue system is the same as the one from the restored backup:
    cmp -s "$rule" "$TARGET_FS_ROOT/$rule" && continue
    # Save the one that was restored from the backup:
    rulefile="$( basename "$rule" )"
    cp $v "$TARGET_FS_ROOT/$rule" $TARGET_FS_ROOT/root/rear-"$rulefile".old
    # Overwrite the one that was restored from the backup with the one from the rescue system:
    LogPrint "Replacing restored udev rule '$TARGET_FS_ROOT/$rule' with the one from the ReaR rescue system"
    cp $v "$rule" "$TARGET_FS_ROOT/$rule" || LogPrintError "Failed to copy '$rule' to '$TARGET_FS_ROOT/$rule'"
done

