# 810_prepare_multiple_iso.sh
#
# Multiple ISOs preparation.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Without a maximum ISO size all is in one single ISO:
test "$ISO_MAX_SIZE" || return 0

# When a maximum ISO size is set it means the backup could be split on multiple ISOs.
# When the backup is split on multiple ISOs, then "rear mkrescue" would destroy it
# because in the first ISO that is named "rear-HOSTNAME.iso" there is
# in case of "rear mkbackup" the (bootable) ReaR recovery system
# plus the first part of the splitted backup (usually named "backup.tar.gz.00")
# plus the backup.splitted file that contains information about the splitted backup.
# But "rear mkrescue" would overwrite that first ISO with one that contains only
# the new ReaR recovery system but no longer the first part of the splitted backup
# nor the backup.splitted file so that then "rear recover" fails with
# "ERROR: Backup archive 'backup.tar.gz' not found"
# see https://github.com/rear/rear/issues/1545
# Accordingly when a maximum ISO size is set the mkrescue workflow is forbidden
# to be on the safe side to not possibly destroy an existing backup.
# Even with a sufficiently big maximum ISO size so that all is in one ISO
# a "rear mkrescue" would overwrite an existing ISO that contains a backup.
test "mkrescue" = "$WORKFLOW" && Error "The mkrescue workflow is forbidden when ISO_MAX_SIZE is set"

local backup_path=$( url_path $BACKUP_URL )

# The backuparchive variable value is set in prep/NETFS/default/070_set_backup_archive.sh
# which is skipped in case of the mkrescue workflow but the mkrescue workflow is forbidden
# when ISO_MAX_SIZE is set and this script is skipped when ISO_MAX_SIZE is not set
# see https://github.com/rear/rear/pull/2063#issuecomment-469222487
local isofs_path=$( dirname $backuparchive )

# Because usr/sbin/rear sets 'shopt -s nullglob' the 'echo -n' command
# outputs nothing if nothing matches the bash globbing pattern '$backuparchive.??'
# so that number_of_ISOs becomes 0 if nothing matches the bash globbing pattern.
# Normally number_of_ISOs is the number of backup archive files.
local number_of_ISOs=$( echo -n $backuparchive.?? | wc -w )
# Show to the user if the number of backup archive files is not at least 1
# because in this case something may have failed or will fail:
test $number_of_ISOs -ge 1 || LogPrintError "Number of backup archive files '$backuparchive.??' is not at least 1"
# Report if the number of backup archive files exceeds 100
# because the 'for' loop below counts 01 02 03 ... up to (number_of_ISOs - 1):
test $number_of_ISOs -le 100 || LogPrint "Number of backup archive files '$backuparchive.??' exceeds 100"

LogPrint "Preparing $number_of_ISOs ISO images"

# Report what the initial (bootable) one will be:
ISO_NAME="$ISO_PREFIX.iso"
backup_filename="$( basename $backuparchive.00 )"
backup_size="$( stat -c '%s' $backuparchive.00 )"
echo "$backup_filename $backup_size $iso_label" >> "$isofs_path/backup.splitted"
LogPrint "Initial (bootable) ISO image will be $ISO_NAME labelled $ISO_VOLID containing $backup_filename ($backup_size bytes)"

# Count 01 02 03 ... 99 100 101 ...
for iso_number in $( seq -f '%02g' 1 $(( $number_of_ISOs - 1 )) ) ; do
    TEMP_ISO_DIR="$TMP_DIR/isofs_$iso_number"
    TEMP_BACKUP_DIR="$TEMP_ISO_DIR$backup_path"
    BACKUP_NAME="$backuparchive.$iso_number"
    ISO_NAME="${ISO_PREFIX}_$iso_number.iso"
    ISO_OUTPUT_PATH="$ISO_DIR/$ISO_NAME"
    # Report what the current one will be:
    backup_filename="$( basename $BACKUP_NAME )"
    backup_size="$( stat -c '%s' $BACKUP_NAME )"
    iso_label="${ISO_VOLID}_$iso_number"
    echo "$backup_filename $backup_size $iso_label" >> "$isofs_path/backup.splitted"
    LogPrint "Making additional ISO image: $ISO_NAME labelled $iso_label containing $backup_filename ($backup_size bytes)"
    # Make the current one:
    mkdir -p $TEMP_BACKUP_DIR
    mv $BACKUP_NAME $TEMP_BACKUP_DIR
    pushd $TEMP_ISO_DIR 1>/dev/null
    if ! $ISO_MKISOFS_BIN $v $ISO_MKISOFS_OPTS -o "$ISO_OUTPUT_PATH" -R -J -volid "${ISO_VOLID}_$iso_number" -v -iso-level 3 . 1>/dev/null ; then
        Error "Failed to create ISO image $ISO_NAME (with $ISO_MKISOFS_BIN)"
    fi
    popd 1>/dev/null
    # Report the result:
    iso_image_size=( $( du -h "$ISO_OUTPUT_PATH" ) )
    LogPrint "Wrote ISO image: $ISO_OUTPUT_PATH ($iso_image_size)"
    # Add ISO images path to result files:
    RESULT_FILES=( "${RESULT_FILES[@]}" "$ISO_OUTPUT_PATH" )
done

# vim: set et ts=4 sw=4:
