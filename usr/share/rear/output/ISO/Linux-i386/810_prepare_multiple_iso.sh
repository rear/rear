# 810_prepare_multiple_iso.sh
#
# multiple isos preparation
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# in mkrescue workflow there is no need to check the backups made, otherwise,
# NB_ISOS=(ls . | wc -l) [side effect is that lots of empty ISOs are made]
test "mkrescue" = "$WORKFLOW" && return

# Without a maximum ISO size all is in one single ISO:
test "$ISO_MAX_SIZE" || return

local backup_path=$( url_path $BACKUP_URL )
local isofs_path=$( dirname $backuparchive )

NB_ISOS=$( ls ${backuparchive}.?? | wc -l )

LogPrint "Preparing $NB_ISOS ISO images ..."

# Report what the initial (bootable) one will be:
ISO_NAME="$ISO_PREFIX.iso"
backup_filename="$( basename $backuparchive.00 )"
backup_size="$( stat -c '%s' $backuparchive.00 )"
echo "$backup_filename $backup_size $iso_label" >> "$isofs_path/backup.splitted"
LogPrint "Initial (bootable) ISO image will be $ISO_NAME labelled $ISO_VOLID containing $backup_filename ($backup_size bytes)"

# Count 01 02 03 ...
for iso_number in $( seq -f '%02g' 1 $(( $NB_ISOS - 1 )) ) ; do
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
    $ISO_MKISOFS_BIN $v -o "$ISO_OUTPUT_PATH" -R -J -volid "${ISO_VOLID}_$iso_number" -v -iso-level 3 . 1>/dev/null
    StopIfError "Failed to create ISO image $ISO_NAME (with $ISO_MKISOFS_BIN)"
    popd 1>/dev/null
    # Report the result:
    iso_image_size=( $( du -h "$ISO_OUTPUT_PATH" ) )
    LogPrint "Wrote ISO image: $ISO_OUTPUT_PATH ($iso_image_size)"
    # Add ISO images path to result files:
    RESULT_FILES=( "${RESULT_FILES[@]}" "$ISO_OUTPUT_PATH" )
done

