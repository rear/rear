# copy required system users and groups to the rescue system

if [[ "$CLONE_ALL_USERS_GROUPS" =~ ^[yY1] ]]; then
    CLONE_USERS=($(cut -d ':' -f '1' /etc/passwd))
    CLONE_GROUPS=($(cut -d ':' -f '1' /etc/group))
fi

Log "Cloning users: ${CLONE_USERS[@]}"
for u in "${CLONE_USERS[@]}" ; do
	# go over all users
	if pwd=$(getent passwd "$u") ; then
		# pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
		# if the user exists, add to the passwd in rescue system
		# skip if this user exists already in the rescue system
		grep -q "^$pwd:" $ROOTFS_DIR/etc/passwd && continue
		echo "$pwd" >>$ROOTFS_DIR/etc/passwd
		# strip gid from passwd line
		pwd="${pwd#*:*:*:}"
		gid=${pwd%%:*}
		# add gid to groups to collect
		CLONE_GROUPS=( "${CLONE_GROUPS[@]}" "$gid" )
	else
		Debug "WARNING: Could not collect user info for '$u'"
	fi
done

Log "Cloning groups: ${CLONE_GROUPS[@]}"
for g in "${CLONE_GROUPS[@]}" ; do
	# go over all users
	if grp=$(getent group "$g") ; then
		# grp="daemon:x:2:"
		# if the group  exists, add to the group in rescue system
		# skip if this user exists already in the rescue system
		grep -q "^$grp" $ROOTFS_DIR/etc/group && continue
		echo "$grp" >>$ROOTFS_DIR/etc/group
	else
		Debug "WARNING: Could not collect group info for '$g'"
	fi
done


