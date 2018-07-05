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
save_original_file_dir="$VAR_DIR/saved_original_files/"
# Strip leading '/' to get a relative path that is needed inside the recovery system:
save_original_file_dir="${save_original_file_dir#/}"
# Create the save_original_file_dir with mode 0700 (rwx------)
# so that only root can access files and subdirectories therein
# because the files therein could contain security relevant information:
mkdir -p -m 0700 $save_original_file_dir
LogPrint "The original restored files get saved in $save_original_file_dir (in $TARGET_FS_ROOT)"

# The funny [] around the first letter make sure that shopt -s nullglob removes this file from the list if it does not exist.
# Files without a [] are mandatory, like fstab:
for file in [b]oot/{grub.conf,menu.lst,device.map} [e]tc/grub.* [b]oot/grub/{grub.conf,menu.lst,device.map} \
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
        # Skip directory or file not found:
        test -f "$file" || continue
        # sed -i bails on symlinks, so we follow the symlink and patch the result
        # absolute links are rebased on $TARGET_FS_ROOT (/etc/fstab => $TARGET_FS_ROOT/etc/fstab)
        # on dead links we warn and skip them
        if test -L "$file" ; then
            linkdest="$( readlink -m "$file" | sed -e "s#^/#$TARGET_FS_ROOT/#" )"
            if test -f "$linkdest" ; then
                LogPrint "Using symlink '$file' destination '$linkdest'"
                file="$linkdest"
            else
                LogPrint "Skipping dead symlink '$file'"
                continue
            fi
        fi
        # Skip empty files:
        test -s "$file" || continue
        # Save the original file:
        # Clean up already existing stuff in save_original_file_dir
        # that would be (partially) overwritten by the current copy
        # (such stuff is considered as outdated leftover e.g. from a previous recovery)
        # but keep already existing stuff in the save_original_file_dir because
        # any user data is sacrosanct (also outdated stuff from a previous recovery):
        rm -rf "$save_original_file_dir/$file"
        # Copy the original file with its directory path:
        cp -a --parents "$file" $save_original_file_dir
        # Inform the user but do not error out here at this late state of "rear recover"
        # when it failed to apply the layout mappings to one particular restored file:
        if apply_layout_mappings "$file" ; then
            LogPrint "Applied disk layout mappings to restored '$file' (in $TARGET_FS_ROOT)"
        else
            LogPrintError "Failed to apply disk layout mappings to restored '$file' (in $TARGET_FS_ROOT)"
        fi
done

popd >&2

