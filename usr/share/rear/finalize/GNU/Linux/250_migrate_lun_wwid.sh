# migrate lun_wwid_mapping

# skip if no mappings
test -s "$LUN_WWID_MAP" || return 0

# FIXME: What the heck does that "TAG-15-migrate-wwid" mean?
Log "TAG-15-migrate-wwid: $LUN_WWID_MAP"

# create the sed script
local sed_script=""
local old_wwid new_wwid device
while read old_wwid new_wwid device ; do
    sed_script="$sed_script;/${old_wwid}/s/${old_wwid}/${new_wwid}/g"
done < <( sort -u $LUN_WWID_MAP )
# debug line:
Debug "$sed_script"

# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $TARGET_FS_ROOT >&2

# now run sed
LogPrint "Migrating LUN WWIDs in certain restored files in $TARGET_FS_ROOT to current WWIDs ..."

local symlink_target=""
local restored_file=""
# the funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist
# the files without a [] are mandatory, like fstab FIXME: but below there is [e]tc/fstab not etc/fstab - why?
for restored_file in [e]tc/elilo.conf \
                     [e]tc/fstab
do
    # Silently skip directories and file not found:
    test -f "$restored_file" || continue
    # 'sed -i' bails out on symlinks, so we follow the symlink and patch the symlink target
    # on dead links we inform the user and skip them
    # TODO: We should do this inside 'chroot $TARGET_FS_ROOT' so that absolute symlinks will work correctly
    # cf. https://github.com/rear/rear/issues/1338
    if test -L "$restored_file" ; then
        if symlink_target="$( readlink -f "$restored_file" )" ; then
            # symlink_target is an absolute path in the recovery system
            # e.g. the symlink target of etc/mtab is /mnt/local/proc/12345/mounts
            # because we use only 'pushd $TARGET_FS_ROOT' but not 'chroot $TARGET_FS_ROOT'.
            # If the symlink target does not start with /mnt/local/ (i.e. if it does not start with $TARGET_FS_ROOT)
            # it is an absolute symlink (i.e. inside $TARGET_FS_ROOT a symlink points to /absolute/path/file)
            # and the target of an absolute symlink is not within the recreated system but in the recovery system
            # where it does not make sense to patch files, cf. https://github.com/rear/rear/issues/1338
            # so that we skip patching symlink targets that are not within the recreated system:
            if ! echo $symlink_target | grep -q "^$TARGET_FS_ROOT/" ; then
                LogPrint "Skip patching symlink $restored_file target $symlink_target not within $TARGET_FS_ROOT"
                continue
            fi
            # If the symlink target contains /proc/ /sys/ /dev/ or /run/ we skip it because then
            # the symlink target is considered to not be a restored file that needs to be patched
            # cf. https://github.com/rear/rear/pull/2047#issuecomment-464846777
            if echo $symlink_target | egrep -q '/proc/|/sys/|/dev/|/run/' ; then
                LogPrint "Skip patching symlink $restored_file target $symlink_target on /proc/ /sys/ /dev/ or /run/"
                continue
            fi
            LogPrint "Patching symlink $restored_file target $symlink_target"
            restored_file="$symlink_target"
        else
            LogPrint "Skip patching dead symlink $restored_file"
            continue
        fi
    fi
    LogPrint "Patching LUN WWIDs in $restored_file to current WWIDs"
    # Do not error out at this late state of "rear recover" (after the backup was restored) but inform the user:
    sed -i "$sed_script" "$restored_file" || LogPrintError "Migrating LUN WWIDs in $restored_file to current WWIDs failed"
done

popd >&2

