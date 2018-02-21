# 395_recreate_users_and_groups.sh
#
# Recreate the same users and groups that exist
# in the ReaR recovery system also in the target system.

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

#local dst_root="$ROOTFS_DIR"	# Default to recreating users & groups in the rescue environment
#IsInArray $WORKFLOW ${backup_restore_workflows[@]} && dst_root="$TARGET_FS_ROOT"	# Recreate users & groups in the target environment

[ -z "$TMPDIR" ] && TMPDIR=$(mktemp -d -t rear_395.XXXXXXXXXXXXXXX)

# code snippet from restore/NETFS/default/400_restore_backup.sh...
# Disable BACKUP_PROG_DECRYPT_OPTIONS by replacing the default with 'cat' when encryption is disabled
# (by default encryption is disabled but the default BACKUP_PROG_DECRYPT_OPTIONS is not 'cat'):
if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
    # Backup archive decryption is only supported with 'tar':
    test "tar" = "$BACKUP_PROG" || Error "Backup archive decryption is only supported with BACKUP_PROG=tar"
    LogPrint "Decrypting backup archive with key defined in variable \$BACKUP_PROG_CRYPT_KEY"
else
    Log "Decrypting backup archive is disabled"
    BACKUP_PROG_DECRYPT_OPTIONS="cat"
    BACKUP_PROG_CRYPT_KEY=""
fi
# ...code snippet from restore/NETFS/default/400_restore_backup.sh

# Extract the passwd, shadow and group files from our backup to our rescue /tmp so we can use those files to repopulate the users in the target system
dd if=$backuparchive | \
	$BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | \
	$BACKUP_PROG --acls --preserve-permissions --same-owner --block-number --totals --verbose $BACKUP_PROG_OPTIONS "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $TMPDIR -x -f - etc/passwd etc/shadow etc/group

RECREATE_USERS=($(cut -d ':' -f '1' $TMPDIR/etc/passwd))
RECREATE_GROUPS=($(cut -d ':' -f '1' $TMPDIR/etc/group))

# Create a local getent() function to override the system getent.  Required since we want to extract entries from our passwd, shadow and group files in $TMPDIR/etc
getent () {
	grep "^$2:" $TMPDIR/etc/$1
}

# Create a getent alias to override the system getent.  Required since we want to extract entries from our passwd, shadow and group files in $TMPDIR/etc, not /etc
#alias getent="chroot $TMPDIR getent"

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
		#if ! grep -q "^$user:" $dst_root/etc/passwd ; then
		#	echo "$pwd" >>$dst_root/etc/passwd
		fi
		# strip gid from passwd line
		pwd="${pwd#*:*:*:}"
		gid="${pwd%%:*}"
		# No need to do this, we're recreating ALL groups
		# add gid to groups to collect
		#RECREATE_GROUPS=( "${RECREATE_GROUPS[@]}" "$gid" )
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
                #grep -q "^$group:" $dst_root/etc/group && continue
		echo "$grp" >>$TARGET_FS_ROOT/etc/group
		#echo "$grp" >>$dst_root/etc/group
	else
		Debug "WARNING: Could not collect group info for '$g'"
	fi
done

# Remove our local definition of getent
unset -f getent

# Remove our getent alias - we will recreate it if we're also populating passwords (below)
#unalias getent


IsInArray "passwords" "${RECREATE_USERS_GROUPS[@]}" || return

# Create a local getent() function to override the system getent.  Required since we want to extract entries from our passwd, shadow and group files in $TMPDIR/etc
getent () {
	grep "^$2:" $TMPDIR/etc/$1
}

# Create a getent alias to override the system getent.  Required since we want to extract entries from our passwd, shadow and group files in $TMPDIR/etc, not /etc
#alias getent="chroot $TMPDIR getent"

Log "Recreating existing user passwords: ${RECREATE_USERS[@]}"
for u in "${RECREATE_USERS[@]}" ; do
	# go over all users
	if pwd=$(getent passwd "$u") ; then
		# pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
		# if the user exists, change the password to match in restore system
		# skip if this user doesn't exist in the restore system
		user="${pwd%%:*}"
		grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd || continue
		#grep -q "^$user:" $dst_root/etc/passwd || continue
		# strip passwd from shadow line
		#pass=$(grep "^$user:" /etc/shadow)
		pass=$(getent shadow $user)
		pass="${pass#*:}"
		pass="${pass%%:*}"
		# set passwd
		echo "$user:$pass" | chpasswd -e --root $TARGET_FS_ROOT
		#echo "$user:$pass" | chpasswd -e --root $dst_root
	else
		Debug "WARNING: Could not collect user info for '$u'"
	fi
done

# Remove our local definition of getent
unset -f getent

# Remove our getent alias
#unalias getent

