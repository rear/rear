# 40_restore_backup.sh
#

local scheme=$(url_scheme $BACKUP_URL)
local path=$(url_path $BACKUP_URL)
local opath=$(backup_path $scheme $path)

mkdir -p "${BUILD_DIR}/outputfs/${NETFS_PREFIX}"

# Disable BACKUP_PROG_CRYPT_OPTIONS by replacing the default value to cat in
# case encryption is disabled
if (( $BACKUP_PROG_CRYPT_ENABLED == 1 )); then
  LogPrint "Decrypting archive with key: $BACKUP_PROG_CRYPT_KEY"
else
  LogPrint "Decrypting disabled"
  BACKUP_PROG_DECRYPT_OPTIONS="cat"
  BACKUP_PROG_CRYPT_KEY=""
fi

if [[ -f "${TMP_DIR}/backup.splitted" ]]; then
    restoreinput=$FIFO
else
    restoreinput="$backuparchive"
fi

Log "Restoring $BACKUP_PROG archive '$restorearchive'"
Print "Restoring from '$restorearchive'"
ProgressStart "Preparing restore operation"
(
case "$BACKUP_PROG" in
    # tar compatible programs here
    (tar)
        # Add the --selinux option to be safe with SELinux context restoration
        if [[ ! $BACKUP_SELINUX_DISABLE =~ ^[yY1] ]]; then
            if tar --usage | grep -q selinux;  then
                BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --selinux"
            fi
        fi
        if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
            BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --exclude-from=$TMP_DIR/restore-exclude-list.txt "
        fi
        if [ "$BACKUP_TYPE" == "incremental" ]; then
            LAST="$restorearchive"
            BASE=$(dirname "$restorearchive")/$(tar --test-label -f "$restorearchive")
            if [ "$BASE" == "$LAST" ]; then
                Log dd if=$BASE \| $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY \| $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
                dd if=$BASE | $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
            else
                Log dd if="$BASE" \| $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY \| $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
                dd if="$BASE" | $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
                Log dd if="$LAST" \| $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY \| $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
                dd if="$LAST" | $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
            fi
        else
            Log dd if=$restoreinput \| $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY \| $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
            dd if=$restoreinput | $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS $BACKUP_PROG_COMPRESS_OPTIONS -C /mnt/local/ -x -f -
        fi
    ;;
    (rsync)
        if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
            BACKUP_RSYNC_OPTIONS=( "${BACKUP_RSYNC_OPTIONS[@]}" --exclude-from=$TMP_DIR/restore-exclude-list.txt )
        fi
        Log $BACKUP_PROG $v "${BACKUP_RSYNC_OPTIONS[@]}"  "$backuparchive"/ /mnt/local/
        $BACKUP_PROG  $v "${BACKUP_RSYNC_OPTIONS[@]}" "$backuparchive"/ /mnt/local/
    ;;
    (*)
        Log "Using unsupported backup program '$BACKUP_PROG'"
        $BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
            $BACKUP_PROG_OPTIONS_RESTORE_ARCHIVE /mnt/local \
            $BACKUP_PROG_OPTIONS $backuparchive
    ;;
esac >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log"
# important trick: the backup prog is the last in each case entry and the case .. esac is the last command
# in the (..) subshell. As a result the return code of the subshell is the return code of the backup prog!
) &
BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

(
# In case of a splitted backup
if [[ -f "${TMP_DIR}/backup.splitted" ]]; then
    Print ""
    while read file; do
        name=${file%% *}
        vol_name=${file##* }
        file_path="${opath}/${name}"

        touch ${TMP_DIR}/wait_dvd

        while ! [[ -f "$file_path" ]]; do
            umount "${BUILD_DIR}/outputfs"
            ProgressInfo "Please insert the media called $vol_name in your CD-ROM drive..."
            sleep 2
            drive=$(cat /proc/sys/dev/cdrom/info | grep -i "drive name:" | awk '{print $3 " " $4}')
            for dev in $drive; do
                label=$(blkid /dev/${dev} | awk 'BEGIN{FS="[=\"]"} {print $3}')
                if [[ $label = $vol_name ]]; then
                    LogPrint "\n${vol_name} detected in /dev/${dev} ..."
                    mount /dev/${dev} "${BUILD_DIR}/outputfs"
                fi
            done
        done

        if [[ -f "$file_path" ]]; then
            if [[ $BACKUP_INTEGRITY_CHECK =~ ^[yY1] && -f "${TMP_DIR}/backup.md5" ]] ; then
                LogPrint "Checking $name ..."
                (cd $(dirname $backuparchive) && grep $name "${TMP_DIR}/backup.md5" | md5sum -c)
                ret=$?
                if [[ $ret -ne 0 ]]; then
                    Error "Integrity check failed ! Restore aborted.
If you want to bypass this check, disable the option in your Rear configuration."
                    return
                fi
            fi
            rm ${TMP_DIR}/wait_dvd
            LogPrint "Processing $name ..."
            dd if="${file_path}" of="$FIFO"
        else
            StopIfError "$name could not be found on the $vol_name media !"
        fi

    done < "${TMP_DIR}/backup.splitted"
    kill -9 $(cat "${TMP_DIR}/cat_pid")
    rm "${TMP_DIR}/cat_pid"
    rm "${TMP_DIR}/backup.splitted"
    rm "${TMP_DIR}/backup.md5"
fi
) &

# make sure that we don't fall for an old size info
unset size
# while the backup runs in a sub-process, display some progress information to the user
case "$BACKUP_PROG" in
    tar)
        while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
            blocks="$(tail -1 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" | awk 'BEGIN { FS="[ :]" } /^block [0-9]+: / { print $2 }')"
            size="$((blocks*512))"
            if [ -f ${TMP_DIR}/wait_dvd ]; then
                            starttime=$((starttime+1))
            else
                            ProgressInfo "Restored $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
                        fi
        done
        ;;
    *)
        ProgressInfo "Restoring..."
        while sleep 1 ; kill -0 $BackupPID 2>/dev/null ; do
            ProgressStep
        done
        ;;
esac
ProgressStop

transfertime="$((SECONDS-starttime))"


# harvest return code from background job. The kill -0 $BackupPID loop above should
# have made sure that this wait won't do any real "waiting" :-)
wait $BackupPID
backup_prog_rc=$?

sleep 1
test "$backup_prog_rc" -gt 0 && LogPrint "WARNING !
There was an error (Nr. $backup_prog_rc) while restoring the archive.
Please check '$LOGFILE' for more information. You should also
manually check the restored system to see wether it is complete.
"

# TODO if size is not given then calculate it from backuparchive_size

tar_message="$(tac $LOGFILE | grep -m1 '^Total bytes written: ')"
if [ $backup_prog_rc -eq 0 -a "$tar_message" ] ; then
    LogPrint "$tar_message in $transfertime seconds."
elif [ "$size" ]; then
    LogPrint "Restored $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi
