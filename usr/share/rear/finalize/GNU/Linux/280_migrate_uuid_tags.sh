# migrate fs_uuid_mapping

# Check if UUIDs in disklayout.conf still appear in the restored config files.
# During "rear mkrescue/mkbackup/mkbackuponly/savelayout" various layout/save/ scripts
# stored the UUIDs in disklayout.conf in var/lib/rear/layout/config/disklayout.uuids
# (e.g. see layout/save/GNU/Linux/230_filesystem_layout.sh)
# and finally the script layout/save/default/600_snapshot_files.sh
# extracted which UUIDs in disklayout.conf appear in a config file in CHECK_CONFIG_FILES
# and saved those UUIDs as DISKLAYOUT_UUIDS_IN_CONFIG_FILES in etc/rear/rescue.conf
# which is now used for comparison during "rear recover"
# if those UUIDs still appear in a restored config file in CHECK_CONFIG_FILES
# in the restored files of the recreated system under /mnt/local.
# One reason for this check is that the subsequent UUID mapping code cannot work
# when restored config files have different UUIDs than those in disklayout.conf because
# FS_UUID_MAP contains UUIDs that were changed during disk layout recreation in the form
#   disklayout_conf_UUID recreated_UUID device
# (see layout/prepare/GNU/Linux/131_include_filesystem_code.sh)
# from which a sed script is created below that replaces disklayout_conf_UUID by recreated_UUID
# but this sed script cannot work when restored config files have different UUIDs
# than those in disklayout.conf because the UUIDs in disklayout.conf will not match.
# The main reason for this check is that normally UUIDs get recreated as stored in disklayout.conf
# because nowadays tools (e.g. mkfs) can set UUIDs so normally the UUID mapping code has nothing to do.
# But when restored config files have different UUIDs than those in disklayout.conf
# the restored config files have UUIDs that are different than the recreated UUIDs
# so the restored config files cannot work because their UUIDs do not exist in the recreated system.
# It is not possible to automatically adjust wrong UUIDs in restored config files with reasonable effort
# because we know only the UUIDs in disklayout.conf and the UUIDs in the recreated system
# but we do not know with what UUID a wrong UUID in a restored config file should be replaced
# because we do not have the config files from the time when disklayout.conf was created.
# The reason why restored config files can have different UUIDs than those in disklayout.conf
# is that the backup does not match the ReaR recovery system.
# E.g. when the backup was made at a different time than when the ReaR recovery system was made
# (i.e. "rear mkrescue" was run at a different time than when the backup was made).
# Using "rear mkbackup" avoids such inconsistencies but most external backup methods
# do not support "rear mkbackup" so the user is responsible to ensure his backup and
# his ReaR recovery system are consistent, cf https://github.com/rear/rear/issues/2787

# Go to the restored files directory.
# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $TARGET_FS_ROOT >/dev/null
# Get the restored config files in CHECK_CONFIG_FILES:
local config_files=()
local obj
for obj in "${CHECK_CONFIG_FILES[@]}" ; do
    if test -d "$obj" ; then
        config_files+=( $( find "$obj" -type f ) )
    elif test -e "$obj" ; then
        config_files+=( "$obj" )
    fi
done
# Check if each UUID that was in at least one of the config files
# in CHECK_CONFIG_FILES at the time when disklayout.conf was created
# is now in at least one of the restored config files in CHECK_CONFIG_FILES:
local uuid
for uuid in $DISKLAYOUT_UUIDS_IN_CONFIG_FILES ; do
    grep -q "$uuid" "${config_files[@]}" || LogPrintError "UUID $uuid not found in a restored config file (likely this must be manually corrected)"
done
# Go back from the restored files directory:
popd >/dev/null

# skip if no mappings
test -s "$FS_UUID_MAP" || return 0

# FIXME: What the heck does that "TAG-15-migrate" mean?
Log "TAG-15-migrate: $FS_UUID_MAP"

# create the sed script
local sed_script=""
local old_uuid new_uuid device
while read old_uuid new_uuid device ; do
    sed_script="$sed_script;/${old_uuid}/s/${old_uuid}/${new_uuid}/g"
done < <( sort -u $FS_UUID_MAP )
# debug line:
Debug "$sed_script"

# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $TARGET_FS_ROOT >&2

# now run sed
LogPrint "Migrating filesystem UUIDs in certain restored files in $TARGET_FS_ROOT to current UUIDs ..."

local symlink_target=""
local restored_file=""
# the funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist
# the files without a [] are mandatory, like fstab FIXME: but below there is [e]tc/fstab not etc/fstab - why?
for restored_file in [b]oot/{grub.conf,menu.lst,device.map} [e]tc/grub.* \
                     [b]oot/grub/{grub.conf,grub.cfg,menu.lst,device.map} \
                     [b]oot/grub2/{grub.conf,grub.cfg,menu.lst,device.map} \
                     [e]tc/sysconfig/grub [e]tc/sysconfig/bootloader \
                     [e]tc/lilo.conf [e]tc/elilo.conf \
                     [e]tc/mtab [e]tc/fstab \
                     [e]tc/mtools.conf \
                     [e]tc/smartd.conf [e]tc/sysconfig/smartmontools \
                     [e]tc/sysconfig/rawdevices \
                     [e]tc/security/pam_mount.conf.xml [b]oot/efi/*/*/grub.cfg
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
    LogPrint "Patching filesystem UUIDs in $restored_file to current UUIDs"
    # Do not error out at this late state of "rear recover" (after the backup was restored) but inform the user:
    sed -i "$sed_script" "$restored_file" || LogPrintError "Migrating filesystem UUIDs in $restored_file to current UUIDs failed"
done

popd >&2

