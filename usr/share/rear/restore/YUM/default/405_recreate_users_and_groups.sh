# 405_recreate_users_and_groups.sh
#
# Recreate the same users and groups that exist
# in the source system also in the target system.

# Do not restore these files from the backup in any case (also for RECREATE_USERS_GROUPS="no").
# There must not be leading slashes for those file names:
local passwd_group_shadow_files="etc/passwd etc/group etc/shadow"
Log "Excluding $passwd_group_shadow_files files from restore"
for f in $passwd_group_shadow_files ; do
    echo "$f" >> $TMP_DIR/restore-exclude-list.txt
done

# Skip recreating if not explicitly requested:
IsInArray "yes" "${RECREATE_USERS_GROUPS[@]}" || return 0

# Extract the passwd, shadow and group files from our backup into a tmp_dir
# so we can use those files to repopulate the users in the target system:
local tmp_dir=$TMP_DIR/recreate_users_and_groups
if ! mkdir $v -p $tmp_dir ; then
    # Tell the user but do not abort the whole "rear recover" because of this:
    LogPrintError "RECREATE_USERS_GROUPS contains 'yes' but cannot recreate them (failed to 'mkdir $tmp_dir')"
    return 1
fi
# Do not show the BACKUP_PROG_CRYPT_KEY value in a log file
# where BACKUP_PROG_CRYPT_KEY is only used if BACKUP_PROG_CRYPT_ENABLED is true
# therefore 'Log ... BACKUP_PROG_CRYPT_KEY ...' is used (and not '$BACKUP_PROG_CRYPT_KEY')
# but '$BACKUP_PROG_CRYPT_KEY' must be used in the actual command call which means
# the BACKUP_PROG_CRYPT_KEY value would appear in the log when rear is run in debugscript mode
# so that stderr of the confidential command is redirected to SECRET_OUTPUT_DEV (normally /dev/null)
# cf. the comment of the UserInput function in lib/_input-output-functions.sh
# how to keep things confidential when rear is run in debugscript mode
# because it is more important to not leak out user secrets into a log file
# than having stderr error messages when a confidential command fails
# cf. https://github.com/rear/rear/issues/2155
# Let 'dd' read and write up to 1M=1024*1024 bytes at a time to speed up things
# cf. https://github.com/rear/rear/issues/2369 and https://github.com/rear/rear/issues/2458
if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
    dd if=$backuparchive bs=1M | \
        { $BACKUP_PROG_DECRYPT_OPTIONS "$BACKUP_PROG_CRYPT_KEY" ; } 2>>/dev/$SECRET_OUTPUT_DEV | \
        $BACKUP_PROG --acls --preserve-permissions --same-owner --block-number --totals --verbose "${BACKUP_PROG_OPTIONS[@]}" "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $tmp_dir -x -f - $passwd_group_shadow_files
else
    dd if=$backuparchive bs=1M | \
        $BACKUP_PROG --acls --preserve-permissions --same-owner --block-number --totals --verbose "${BACKUP_PROG_OPTIONS[@]}" "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $tmp_dir -x -f - $passwd_group_shadow_files
fi

RECREATE_USERS=( $( cut -d ':' -f '1' $tmp_dir/etc/passwd ) )
RECREATE_GROUPS=( $( cut -d ':' -f '1' $tmp_dir/etc/group ) )

# Create a local get_entry() function which does same as getent but for our needs here because
# we want to extract entries from our passwd, shadow and group files in $tmp_dir/etc
get_entry () {
    grep "^$2:" $tmp_dir/etc/$1
}

Log "Recreating users: ${RECREATE_USERS[@]}"
for u in "${RECREATE_USERS[@]}" ; do
    if ! pwd=$( get_entry passwd "$u" ) ; then
        Debug "Could not recreate user '$u' (could not get its user entry)"
        continue
    fi
    # pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
    # If user entry exists, add it to etc/passwd in the target system
    # skip if this user exists already in the target system:
    user="${pwd%%:*}"
    grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd || echo "$pwd" >>$TARGET_FS_ROOT/etc/passwd
    # strip gid from passwd line
    pwd="${pwd#*:*:*:}"
    gid="${pwd%%:*}"
done

Log "Recreating groups: ${RECREATE_GROUPS[@]}"
for g in "${RECREATE_GROUPS[@]}" ; do
    if ! grp=$( get_entry group "$g" ) ; then
        Debug "Could not recreate group '$g' (could not get its group entry)"
        continue
    fi 
    # grp="daemon:x:2:"
    # If group entry exists, add it to etc/group in the target system
    # skip if this group exists already in the target system:
    group="${grp%%:*}"
    grep -q "^$group:" $TARGET_FS_ROOT/etc/group || echo "$grp" >>$TARGET_FS_ROOT/etc/group
done

# Recreate passwords only if explicitly requested:
if IsInArray "passwords" "${RECREATE_USERS_GROUPS[@]}" ; then
    Log "Recreating passwords for users: ${RECREATE_USERS[@]}"
    for u in "${RECREATE_USERS[@]}" ; do
        if ! pwd=$( get_entry passwd "$u" ) ; then
            Debug "Could not recreate password for user '$u' (could not get its user entry)"
            continue
        fi
        # pwd="daemon:x:2:2:Daemon:/sbin:/bin/bash"
        # If the user entry exists, recreate the user's password in the target system
        # skip if this user doesn't exist in the target system:
        user="${pwd%%:*}"
        grep -q "^$user:" $TARGET_FS_ROOT/etc/passwd || continue
        # strip passwd from shadow line
        pass=$( get_entry shadow $user )
        pass="${pass#*:}"
        pass="${pass%%:*}"
        # set passwd
        echo "$user:$pass" | chpasswd -e --root $TARGET_FS_ROOT      
    done
fi

# Unset local function:
unset -f get_entry
