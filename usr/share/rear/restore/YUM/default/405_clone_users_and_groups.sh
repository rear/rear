# copy required system users and groups to the restore system

if is_true "$CLONE_ALL_USERS_GROUPS" ; then
    CLONE_USERS=($(cut -d ':' -f '1' /etc/passwd))
    CLONE_GROUPS=($(cut -d ':' -f '1' /etc/group))

    # If we're populating system users and groups here,
    # we do not want to restore these files from the backup
    Log "Excluding group, password and shadow files from restore"
    for f in etc/passwd etc/group etc/shadow	# no leading slashes
    do
	echo "$f" >> $TMP_DIR/restore-exclude-list.txt
    done
fi

Log "Cloning users: ${CLONE_USERS[@]}"
for u in "${CLONE_USERS[@]}" ; do
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
		# add gid to groups to collect
		CLONE_GROUPS=( "${CLONE_GROUPS[@]}" "$gid" )
	else
		Debug "WARNING: Could not collect user info for '$u'"
	fi
done

Log "Cloning existing user passwords: ${CLONE_USERS[@]}"
for u in "${CLONE_USERS[@]}" ; do
	# go over all users
	if pwd=$(getent passwd "$u") ; then
		# pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
		# if the user exists, change the password to match in restore system
		# skip if this user doesn't exist in the restore system
		user="${pwd%%:*}"
		grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd || continue
		# strip passwd from shadow line
		#pass=$(grep "^$user:" /etc/shadow)
		pass=$(getent shadow $user)
		pass="${pass#*:}"
		pass="${pass%%:*}"
		# set passwd
		echo "$user:$pass" | chpasswd -e --root $TARGET_FS_ROOT
	else
		Debug "WARNING: Could not collect user info for '$u'"
	fi
done

Log "Cloning groups: ${CLONE_GROUPS[@]}"
for g in "${CLONE_GROUPS[@]}" ; do
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


