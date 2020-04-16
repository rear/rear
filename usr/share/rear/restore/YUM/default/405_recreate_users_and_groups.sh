# 405_recreate_users_and_groups.sh
#
# Recreate the same users and groups that exist
# in the source system also in the target system.

# Do not restore these files from the backup
Log "Excluding group, password and shadow files from restore"
for f in etc/passwd etc/group etc/shadow	# no leading slashes
do
	echo "$f" >> $TMP_DIR/restore-exclude-list.txt
done

# Skip if not needed.
# For the 'test' one must have all array members
# as a single word i.e. "${name[*]}" because
# it should succeed when there is any non-empty
# array member, not necessarily the first one:
#test "${RECREATE_USERS_GROUPS[*]}" || return
IsInArray "yes" "${RECREATE_USERS_GROUPS[@]}" || return

[ -z "$TMPDIR" ] && TMPDIR=$(mktemp -d -t rear_405.XXXXXXXXXXXXXXX)

# Do not show the BACKUP_PROG_CRYPT_KEY value in a log file
# where BACKUP_PROG_CRYPT_KEY is only used if BACKUP_PROG_CRYPT_ENABLED is true
# therefore 'Log ... BACKUP_PROG_CRYPT_KEY ...' is used (and not '$BACKUP_PROG_CRYPT_KEY')
# but '$BACKUP_PROG_CRYPT_KEY' must be used in the actual command call which means
# the BACKUP_PROG_CRYPT_KEY value would appear in the log when rear is run in debugscript mode
# so that stderr of the confidential command is redirected to /dev/null
# cf. the comment of the UserInput function in lib/_input-output-functions.sh
# how to keep things confidential when rear is run in debugscript mode
# because it is more important to not leak out user secrets into a log file
# than having stderr error messages when a confidential command fails
# cf. https://github.com/rear/rear/issues/2155
# Extract the passwd, shadow and group files from our backup to our rescue /tmp so we can use those files to repopulate the users in the target system
if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
    dd if=$backuparchive | \
        { $BACKUP_PROG_DECRYPT_OPTIONS "$BACKUP_PROG_CRYPT_KEY" ; } 2>/dev/null | \
        $BACKUP_PROG --acls --preserve-permissions --same-owner --block-number --totals --verbose "${BACKUP_PROG_OPTIONS[@]}" "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $TMPDIR -x -f - etc/passwd etc/shadow etc/group
else
    dd if=$backuparchive | \
        $BACKUP_PROG --acls --preserve-permissions --same-owner --block-number --totals --verbose "${BACKUP_PROG_OPTIONS[@]}" "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $TMPDIR -x -f - etc/passwd etc/shadow etc/group
fi

RECREATE_USERS=($(cut -d ':' -f '1' $TMPDIR/etc/passwd))
RECREATE_GROUPS=($(cut -d ':' -f '1' $TMPDIR/etc/group))

# Create a local getent() function to override the system getent.  Required since we want to extract entries from our passwd, shadow and group files in $TMPDIR/etc
getent () {
	grep "^$2:" $TMPDIR/etc/$1
}

Log "Recreating users: ${RECREATE_USERS[@]}"
for u in "${RECREATE_USERS[@]}" ; do
	# go over all users
	if pwd=$(getent passwd "$u") ; then
		# pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
		# if the user exists, add to the passwd in restore system
		# skip if this user exists already in the restore system
		user="${pwd%%:*}"
		if ! grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd ; then
			echo "$pwd" >>$TARGET_FS_ROOT/etc/passwd
		fi
		# strip gid from passwd line
		pwd="${pwd#*:*:*:}"
		gid="${pwd%%:*}"
	else
		Debug "WARNING: Could not collect user info for '$u'"
	fi
done


Log "Recreating groups: ${RECREATE_GROUPS[@]}"
for g in "${RECREATE_GROUPS[@]}" ; do
	# go over all users
	if grp=$(getent group "$g") ; then
		# grp="daemon:x:2:"
		# if the group  exists, add to the group in restore system
		# skip if this user exists already in the restore system
                group="${grp%%:*}"
                grep -q "^$group:" $TARGET_FS_ROOT/etc/group && continue
		echo "$grp" >>$TARGET_FS_ROOT/etc/group
	else
		Debug "WARNING: Could not collect group info for '$g'"
	fi
done

# Remove our local definition of getent
# We do this here in case we're not recreating the passwords below
unset -f getent


IsInArray "passwords" "${RECREATE_USERS_GROUPS[@]}" || return

# Create a local getent() function to override the system getent.  Required since we want to extract entries from our passwd, shadow and group files in $TMPDIR/etc
# We do this again here since we removed it above, just in case
getent () {
	grep "^$2:" $TMPDIR/etc/$1
}

Log "Recreating existing user passwords: ${RECREATE_USERS[@]}"
for u in "${RECREATE_USERS[@]}" ; do
	# go over all users
	if pwd=$(getent passwd "$u") ; then
		# pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
		# if the user exists, change the password to match in restore system
		# skip if this user doesn't exist in the restore system
		user="${pwd%%:*}"
		grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd || continue
		# strip passwd from shadow line
		pass=$(getent shadow $user)
		pass="${pass#*:}"
		pass="${pass%%:*}"
		# set passwd
		echo "$user:$pass" | chpasswd -e --root $TARGET_FS_ROOT
	else
		Debug "WARNING: Could not collect user info for '$u'"
	fi
done

# Remove our local definition of getent
unset -f getent

