#
# 900_clone_users_and_groups.sh
#
# Copy users and groups into the ReaR recovery system.

local cloning_all="no"
# When CLONE_ALL_USERS_GROUPS is 'true' or 'all' copy users and groups
# that exist on the current system into the ReaR recovery system
# in addition to the users and groups in CLONE_USERS and CLONE_GROUPS
# and regardless of duplicates because when duplicates exists already
# in the ReaR recovery system they are skipped (see the code below).
# When CLONE_ALL_USERS_GROUPS contains a 'true' value, copy also
# the users and groups from the /etc/passwd and /etc/group files:
if is_true "$CLONE_ALL_USERS_GROUPS" ; then
    Log "Copying users and groups from /etc/passwd and /etc/group"
    cloning_all="yes"
    # Only keep valid user names (in particular exclude a NIS extension line '+::::::'):
    CLONE_USERS=( "${CLONE_USERS[@]}" $( grep -o '^[[:alnum:]_][^:]*' /etc/passwd ) )
    # Only keep valid group names (in particular exclude a NIS extension line '+:::'):
    CLONE_GROUPS=( "${CLONE_GROUPS[@]}" $( grep -o '^[[:alnum:]_][^:]*' /etc/group ) )
fi
# When CLONE_ALL_USERS_GROUPS is 'all', copy also all users and groups
# that are available on the current system into the ReaR recovery system:
if test 'all' = "$CLONE_ALL_USERS_GROUPS" ; then
    Log "Copying all users and groups that are available via 'getent'"
    cloning_all="yes"
    # Only keep valid user names:
    CLONE_USERS=( "${CLONE_USERS[@]}" $( getent passwd | grep -o '^[[:alnum:]_][^:]*' ) )
    # Only keep valid group names:
    CLONE_GROUPS=( "${CLONE_GROUPS[@]}" $( getent group | grep -o '^[[:alnum:]_][^:]*' ) )
fi

local user=""
local passwd_entry=""
local groupID=""
local group_entry=""
local group=""

# For the 'test' one must have all array members as a single word i.e. "${name[*]}"
# because it should succeed when there is any non-empty array member, not necessarily the first one:
test "${CLONE_USERS[*]}" && Log "Cloning users: ${CLONE_USERS[@]}"
for user in "${CLONE_USERS[@]}" ; do
    # Skip empty user values, cf. https://github.com/rear/rear/issues/2220
    test $user || continue
    # Skip if the user exists already in the ReaR recovery system:
    grep -q "^$user:" $ROOTFS_DIR/etc/passwd && continue
    # Skip if the user does not exist in the current system:
    if ! passwd_entry="$( getent passwd $user )" ; then
        Debug "Cannot clone user $user because it does not exist"
        continue
    fi
    # When CLONE_ALL_USERS_GROUPS was used above, assume
    # the users and groups in CLONE_USERS and CLONE_GROUPS
    # are consistent so that the user's group is in CLONE_GROUPS:
    if is_true "$cloning_all" ; then
        # Add the user to /etc/passwd in the ReaR recovery system and
        # proceed with the next user without further group tests:
        echo "$passwd_entry" >>$ROOTFS_DIR/etc/passwd
        continue
    fi
    # Prepare to also add the user's group to the CLONE_GROUPS array:
    # passwd_entry="user:password:UID:GID:description:HOMEdirectory:shell"
    groupID="$( cut -d ':' -f '4' <<<"$passwd_entry" )"
    if ! group_entry="$( getent group $groupID )" ; then
        Debug "Cannot clone user $user because its group $groupID does not exist"
        continue
    fi
    # Add the user to /etc/passwd in the ReaR recovery system:
    echo "$passwd_entry" >>$ROOTFS_DIR/etc/passwd
    # Add the user's group to the CLONE_GROUPS array (unless already there):
    # group_entry="group:passwd:GID:userlist"
    group="${group_entry%%:*}"
    # Skip if the group is already in the CLONE_GROUPS array:
    IsInArray "$group" "${CLONE_GROUPS[@]}" && continue
    # Add the user's group to the CLONE_GROUPS array:
    CLONE_GROUPS=( "${CLONE_GROUPS[@]}" "$group" )
done

# For the 'test' one must have all array members as a single word i.e. "${name[*]}"
# because it should succeed when there is any non-empty array member, not necessarily the first one:
test "${CLONE_GROUPS[*]}" && Log "Cloning groups: ${CLONE_GROUPS[@]}"
for group in "${CLONE_GROUPS[@]}" ; do
    # Skip empty group values, cf. https://github.com/rear/rear/issues/2220
    test $group || continue
    # Skip if the group exists already in the ReaR recovery system:
    grep -q "^$group:" $ROOTFS_DIR/etc/group && continue
    # Skip if the group does not exist in the current system:
    if ! group_entry="$( getent group $group )" ; then
        Debug "Cannot clone group $group because it does not exist"
        continue
    fi
    # Add the group to /etc/group in the ReaR recovery system:
    echo "$group_entry" >>$ROOTFS_DIR/etc/group
done

