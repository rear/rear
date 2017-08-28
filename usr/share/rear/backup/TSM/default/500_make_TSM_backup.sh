# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Exit if TSM binary cannot be found.
has_binary dsmc || Error "Can't find TSM client dsmc; Please check your configuration."

# If the TSM client is found, do an incremental backup:
backup_tsm_log=/var/lib/rear/backup_tsm_log

if [[ ! -d "$backup_tsm_log" ]]; then
    mkdir -p $v $backup_tsm_log
fi

# Create TSM friendly include list.
for i in $(cat $TMP_DIR/backup-include.txt); do
    include_list+=("$i ")
done

LogPrint ""
LogPrint "Starting Backup with TSM [ ${include_list[@]} ]"
LC_ALL=${LANG_RECOVER} dsmc incremental \
-verbose -tapeprompt=no "${TSM_DSMC_BACKUP_OPTIONS[@]}" \
${include_list[@]} > "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"
StopIfError "Error during TSM backup... Check your configuration."

### Copy progress log to backup media
if cp $v "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" "${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log"; then
    if dsmc incremental ${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log; then
        LogPrint "${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log added to the backup"
    else
        LogPrint "Failed to add ${backup_tsm_log}/${BACKUP_PROG_ARCHIVE}.log to the backup"
    fi
fi
