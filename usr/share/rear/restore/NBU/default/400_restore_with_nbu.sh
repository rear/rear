# 400_restore_with_nbu.sh

# Run the actual 'bprestore' of the selected filesystem restore point.
# Walk the catalog backward from the chosen end time to find the
# nearest full backup, so the restore chain is correct instead of
# replaying every backup ever taken. Restore with True Image Restore
# ('bprestore -T') when NBU_TRUE_IMAGE_RESTORE is enabled.

# Populate files 'bprestore' will use. No need to handle mount points individually.
echo "change / to $TARGET_FS_ROOT" > $TMP_DIR/nbu_change_file || Error "Cannot write $TMP_DIR/nbu_change_file."
echo "/" > $TMP_DIR/restore_fs_list || Error "Cannot write $TMP_DIR/restore_fs_list."
# /dev, /run, /proc, /sys are populated by the running rescue kernel, not the backup.
# Restoring them makes 'bprestore' fail (NetBackup status 2800).
for nbu_pseudofs in /dev /run /proc /sys ; do
    echo "!${nbu_pseudofs}" >> $TMP_DIR/restore_fs_list
done

local edate sdate bprestore_args rc
local nbu_chain_line nbu_chain_date nbu_chain_time nbu_chain_epoch nbu_target_epoch
local nbu_tir_status="disabled"
local nbu_bpclimagelist=/usr/openv/netbackup/bin/bpclimagelist
local nbu_bprestore=/usr/openv/netbackup/bin/bprestore

# "bpclimagelist -T" lists only backups with True Image Restore info, and
# "bprestore -T" restores using that TIR info (excluding files deleted or
# renamed between backups). NBU_TIR_FLAG comes from 250_check_nbu_client_name.sh.
# 'bprestore' ignores -s when -T is also given ('bprestore'(1)).

# Do not use ARGS here because that is readonly in the rear main script.
# NBU_ENDTIME is only empty if verify/.../500_request_pit_restore_parameters.sh
# found no catalog. Nothing to restore from then, so stop.
test -n "$NBU_ENDTIME" || Error "No NetBackup catalog entry available to restore from, cannot do NetBackup Point-In-Time Restore."
edate="$NBU_ENDTIME"

# 'bprestore' with only -e defaults -s to 01/01/1970, which replays every
# image ever taken. Walk the catalog newest-first and stop at the nearest
# full backup to get -s.
nbu_target_epoch=$( date -d "$edate" '+%s' ) || Error "Cannot parse selected restore point in time '$edate'."
sdate=""
# $edate stays unquoted below: -e needs date and time as two arguments.
while read -r nbu_chain_line ; do
    [[ "$nbu_chain_line" =~ ^([0-9]{2}/[0-9]{2}/[0-9]{4})[[:space:]]+([0-9]{2}:[0-9]{2}:[0-9]{2}) ]] || continue
    nbu_chain_date="${BASH_REMATCH[1]}"
    nbu_chain_time="${BASH_REMATCH[2]}"
    nbu_chain_epoch=$( date -d "$nbu_chain_date $nbu_chain_time" '+%s' ) || continue
    test "$nbu_chain_epoch" -le "$nbu_target_epoch" || continue
    if [[ "$nbu_chain_line" == *"Full Backup"* ]] ; then
        sdate="$nbu_chain_date $nbu_chain_time"
        break
    fi
done < <( "$nbu_bpclimagelist" -Listseconds -client "${NBU_CLIENT_SOURCE}" -e ${edate} $NBU_TIR_FLAG 2>/dev/null )
test -n "$sdate" || Error "No full NetBackup backup found at or before '$edate' for client ${NBU_CLIENT_SOURCE}, cannot do Point-In-Time Restore."

bprestore_args="-B -H -L $TMP_DIR/bplog.restore -R $TMP_DIR/nbu_change_file -t 0 -w 0 -s ${sdate} -e ${edate} -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list $NBU_TIR_FLAG"

test -n "$NBU_TIR_FLAG" && nbu_tir_status="enabled"

UserOutput ""
UserOutput "Filesystem restore of $NBU_CLIENT_SOURCE into $TARGET_FS_ROOT with True Image Restore (TIR) $nbu_tir_status:"
LogPrint "$nbu_bprestore $bprestore_args"
"$nbu_bprestore" $bprestore_args
rc=$?
if [ $rc -eq 0 ] ; then
    LogPrint "'bprestore' completed successfully (return code = 0)."
else
    LogPrintError "'bprestore' failed (return code = $rc). Check the restore job's log on the NetBackup Primary server for details."
    LogPrintError "Carefully verify the restored system before relying on it to be fully operational."
fi

