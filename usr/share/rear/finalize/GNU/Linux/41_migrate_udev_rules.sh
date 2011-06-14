#
# if the udev rules in the rescue system look different than in the original system then this is a sign
# that the hardware changed. Copy over the new udev rules, if they are different.

# do nothing if we don't have udev in the rescue system
have_udev || return 0

# we treat only these rules
RULE_FILES=( $( echo /etc/udev/rules.d/*persistent*{names,net,cd}.rules ) )
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
	rulefile="$(basename "$rule")"
	if test -s "$rule" && ! diff -q "$rule" /mnt/local/"$rule" >&8 ; then
		LogPrint "Updating udev configuration ($rulefile)"
		cp /mnt/local/"$rule" /mnt/local/root/rear-"$rulefile".old
		cp "$rule" /mnt/local/"$rule"
		StopIfError "Could not copy '$rule' -> '/mnt/local/$rule'"
	fi
done
