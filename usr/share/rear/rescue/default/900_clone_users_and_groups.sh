
# Copy users and groups to the ReaR recovery system:

if is_true "$CLONE_ALL_USERS_GROUPS" ; then
    # In particular exclude a possible NIS extension line '+::::::'
    CLONE_USERS=( $( grep -o '^[[:alnum:]_][^:]*' /etc/passwd ) )
    # In particular exclude a possible NIS extension line '+:::'
    CLONE_GROUPS=( $( grep -o '^[[:alnum:]_][^:]*' /etc/group ) )
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
    # Skip if the user exists already in the ReaR recovery system:
    grep "^$user:" $ROOTFS_DIR/etc/passwd 1>&2 && continue
    # Skip if the user does not exist in the current system:
    if ! passwd_entry="$( getent passwd $user )" ; then
        Debug "Cannot clone $user because it does not exist"
        continue
    fi
    # Prepare to also add the user's group to the CLONE_GROUPS array:
    # passwd_entry="user:password:UID:GID:description:HOMEdirectory:shell"
    groupID="$( cut -d ':' -f '4' <<<"$passwd_entry" )"
    if ! group_entry="$( getent group $groupID )" ; then
        Debug "Cannot clone $user because its group $groupID does not exist"
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
    # Skip if the group exists already in the ReaR recovery system:
    grep "^$group:" $ROOTFS_DIR/etc/group 1>&2 && continue
    # Skip if the group does not exist in the current system:
    if ! group_entry="$( getent group $group )" ; then
        Debug "Cannot clone $group because it does not exist"
        continue
    fi
    # Add the group to /etc/group in the ReaR recovery system:
    echo "$group_entry" >>$ROOTFS_DIR/etc/group
done

