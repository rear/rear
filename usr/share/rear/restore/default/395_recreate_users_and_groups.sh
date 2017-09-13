# 395_recreate_users_and_groups.sh
#
# Recreate the same users and groups that exist
# in the ReaR recovery system also in the target system.

# Skip if not needed.
# For the 'test' one must have all array members
# as a single word i.e. "${name[*]}" because
# it should succeed when there is any non-empty
# array member, not necessarily the first one:
test "${RECREATE_USERS_GROUPS[*]}" || return

local dst_root="$ROOTFS_DIR"	# Default to recreating users & groups in the rescue environment
IsInArray $WORKFLOW ${backup_restore_workflows[@]} && dst_root="$TARGET_FS_ROOT"	# Recreate users & groups in the target environment

RECREATE_USERS=($(cut -d ':' -f '1' /etc/passwd))
RECREATE_GROUPS=($(cut -d ':' -f '1' /etc/group))

# If we're populating system users and groups here,
# we do not want to restore these files from the backup
Log "Excluding group, password and shadow files from restore"
for f in etc/passwd etc/group etc/shadow	# no leading slashes
do
	echo "$f" >> $TMP_DIR/restore-exclude-list.txt
done

Log "Recreating users: ${RECREATE_USERS[@]}"
for u in "${RECREATE_USERS[@]}" ; do
	# go over all users
	if pwd=$(getent passwd "$u") ; then
		# pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
		# if the user exists, add to the passwd in restore system
		# skip if this user exists already in the restore system
		user="${pwd%%:*}"
		#if ! grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd ; then
		#	echo "$pwd" >>$TARGET_FS_ROOT/etc/passwd
		if ! grep -q "^$user:" $dst_root/etc/passwd ; then
			echo "$pwd" >>$dst_root/etc/passwd
		fi
		# strip gid from passwd line
		pwd="${pwd#*:*:*:}"
		gid="${pwd%%:*}"
		# add gid to groups to collect
		RECREATE_GROUPS=( "${RECREATE_GROUPS[@]}" "$gid" )
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
                #grep -q "^$group:" $TARGET_FS_ROOT/etc/group && continue
                grep -q "^$group:" $dst_root/etc/group && continue
		#echo "$grp" >>$TARGET_FS_ROOT/etc/group
		echo "$grp" >>$dst_root/etc/group
	else
		Debug "WARNING: Could not collect group info for '$g'"
	fi
done


IsInArray "passwords" "${RECREATE_USERS_GROUPS[@]}" || return

Log "Recreating existing user passwords: ${RECREATE_USERS[@]}"
for u in "${RECREATE_USERS[@]}" ; do
	# go over all users
	if pwd=$(getent passwd "$u") ; then
		# pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
		# if the user exists, change the password to match in restore system
		# skip if this user doesn't exist in the restore system
		user="${pwd%%:*}"
		#grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd || continue
		grep -q "^$user:" $dst_root/etc/passwd || continue
		# strip passwd from shadow line
		#pass=$(grep "^$user:" /etc/shadow)
		pass=$(getent shadow $user)
		pass="${pass#*:}"
		pass="${pass%%:*}"
		# set passwd
		#echo "$user:$pass" | chpasswd -e --root $TARGET_FS_ROOT
		echo "$user:$pass" | chpasswd -e --root $dst_root
	else
		Debug "WARNING: Could not collect user info for '$u'"
	fi
done
