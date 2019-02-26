#
# Apply disk layout mappings to certain restored files.
#

# MAPPING_FILE is set in layout/prepare/default/300_map_disks.sh
# only if MIGRATION_MODE is true.
test -s "$MAPPING_FILE" || return 0

# Do not apply layout mappings when there is a completely identical mapping in the mapping file
# to avoid that files (in particular restored files) may get needlessly touched and modified
# for identical mappings, see https://github.com/rear/rear/issues/1847
is_completely_identical_layout_mapping && return 0

LogPrint "Applying disk layout mappings in $MAPPING_FILE to certain restored files..."

# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $TARGET_FS_ROOT >&2

# Save the original restored files because in general any user data is sacrosanct,
# cf. how BACKUP_RESTORE_MOVE_AWAY is implemented in restore/default/990_move_away_restored_files.sh
local save_original_file_dir="$VAR_DIR/saved_original_files/"
# Strip leading '/' to get a relative path that is needed inside the recovery system:
save_original_file_dir="${save_original_file_dir#/}"
# Create the save_original_file_dir with mode 0700 (rwx------)
# so that only root can access files and subdirectories therein
# because the files therein could contain security relevant information:
mkdir -p -m 0700 $save_original_file_dir
LogPrint "The original restored files get saved in $save_original_file_dir (in $TARGET_FS_ROOT)"

local symlink_target=""
local restored_file=""
# the funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist
# the files without a [] are mandatory, like fstab FIXME: but below there is [e]tc/fstab not etc/fstab - why?

for restored_file in [b]oot/{grub.conf,menu.lst,device.map} [e]tc/grub.* [b]oot/grub/{grub.conf,menu.lst,device.map} \
                     [b]oot/grub2/{grub.conf,grub.cfg,menu.lst,device.map} \
                     [e]tc/sysconfig/grub [e]tc/sysconfig/bootloader \
                     [e]tc/lilo.conf \
                     [e]tc/yaboot.conf \
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
            # it is an absolute symlink (e.g. inside $TARGET_FS_ROOT a symlink points to /absolute/path/file)
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
    # Silently skip empty files:
    test -s "$restored_file" || continue
    # Save the original file:
    # Clean up already existing stuff in save_original_file_dir
    # that would be (partially) overwritten by the current copy
    # (such stuff is considered as outdated leftover e.g. from a previous recovery)
    # but keep already existing stuff in the save_original_file_dir because
    # any user data is sacrosanct (also outdated stuff from a previous recovery):
    rm -rf "$save_original_file_dir/$restored_file"
    # Copy the original file with its directory path:
    cp $v -a --parents "$restored_file" $save_original_file_dir
    # Inform the user but do not error out here at this late state of "rear recover"
    # when it failed to apply the layout mappings to one particular restored file:
    if apply_layout_mappings "$restored_file" ; then
        LogPrint "Applied disk layout mappings to restored '$restored_file' (in $TARGET_FS_ROOT)"
    else
        LogPrintError "Failed to apply disk layout mappings to restored '$restored_file' (in $TARGET_FS_ROOT)"
    fi
done

popd >&2

