# 400_restore_with_nbu.sh

# Run the actual 'bprestore' of the selected filesystem restore point.
# Restore from the nearest full backup before the chosen end time. Restore with True Image Restore
# ('bprestore -T') when NBU_TRUE_IMAGE_RESTORE is enabled.

# Populate files 'bprestore' will use. No need to handle mount points individually.
echo "change / to $TARGET_FS_ROOT" > $TMP_DIR/nbu_change_file || Error "Cannot write $TMP_DIR/nbu_change_file."
echo "/" > $TMP_DIR/restore_fs_list || Error "Cannot write $TMP_DIR/restore_fs_list."
# /dev, /run, /proc, /sys are populated by the running rescue kernel, not the backup.
# Restoring them makes 'bprestore' fail (NetBackup status 2800).
for nbu_pseudofs in /dev /run /proc /sys ; do
    echo "!${nbu_pseudofs}" >> $TMP_DIR/restore_fs_list
done
# Folders the operator excluded for a partial backup image restore
# (verify/NBU/default/500_request_pit_restore_parameters.sh):
for nbu_skipped in "${NBU_RESTORE_EXCLUDES[@]}" ; do
    echo "!${nbu_skipped}" >> $TMP_DIR/restore_fs_list
done

local edate sdate bprestore_args rc nbu_skipped
local nbu_tir_status="disabled"
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

# NBU_STARTTIME is the nearest full backup at or before the end time (500_request_pit_restore_parameters.sh).
sdate="$NBU_STARTTIME"
test -n "$sdate" || Error "No full NetBackup backup start time available, cannot do Point-In-Time Restore."

bprestore_args="-B -H -L /usr/openv/netbackup/logs/user_ops/root/logs/bprestore.log -R $TMP_DIR/nbu_change_file -t 0 -w 0 -s ${sdate} -e ${edate} -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list $NBU_TIR_FLAG"

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
if test ${#NBU_RESTORE_EXCLUDES[@]} -gt 0 ; then
    UserOutput "Partial backup image restore performed with folders excluded from restore:"
    UserOutput "${NBU_RESTORE_EXCLUDES[*]}"
fi

