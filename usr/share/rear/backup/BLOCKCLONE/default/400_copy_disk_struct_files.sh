# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 400_copy_disk_struct_files.sh

if [ -z "$BLOCKCLONE_SAVE_MBR_DEV" ]; then
    return
fi

local scheme="$( url_scheme "$BACKUP_URL" )"
local path="$( url_path "$BACKUP_URL" )"
local opath="$( backup_path "$scheme" "$path" )"

LogPrint "Copying $VAR_DIR/layout/$BLOCKCLONE_PARTITIONS_CONF_FILE to $opath"

cp $v "$VAR_DIR/layout/$BLOCKCLONE_PARTITIONS_CONF_FILE" "$opath"
StopIfError "Failed to copy \
$VAR_DIR/layout/$BLOCKCLONE_PARTITIONS_CONF_FILE to $opath"

# The bootstrap code area is only saved for msdos labelled disks, so on a GPT
# disk there is no such file and nothing in the MBR gap worth copying.
if [ -f "$VAR_DIR/layout/$BLOCKCLONE_MBR_FILE" ]; then
    LogPrint "Copying $VAR_DIR/layout/$BLOCKCLONE_MBR_FILE to $opath"

    cp $v "$VAR_DIR/layout/$BLOCKCLONE_MBR_FILE" "$opath"

    StopIfError "Failed to copy $VAR_DIR/layout/$BLOCKCLONE_MBR_FILE to $opath"
else
    Log "No bootstrap code area saved, not copying $BLOCKCLONE_MBR_FILE"
fi
