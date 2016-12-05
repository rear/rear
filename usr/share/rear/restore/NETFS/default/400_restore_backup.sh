# 400_restore_backup.sh
#

local scheme=$(url_scheme $BACKUP_URL)
local path=$(url_path $BACKUP_URL)
local opath=$(backup_path $scheme $path)

mkdir -p "${BUILD_DIR}/outputfs/${NETFS_PREFIX}"

# Disable BACKUP_PROG_DECRYPT_OPTIONS by replacing the default with 'cat' when encryption is disabled
# (by default encryption is disabled but the default BACKUP_PROG_DECRYPT_OPTIONS is not 'cat'):
if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
    # Backup archive decryption is only supported with 'tar':
    test "tar" = "$BACKUP_PROG" || Error "Backup archive decryption is only supported with BACKUP_PROG=tar"
    LogPrint "Decrypting backup archive with key defined in variable \$BACKUP_PROG_CRYPT_KEY"
else
    Log "Decrypting backup archive is disabled"
    BACKUP_PROG_DECRYPT_OPTIONS="cat"
    BACKUP_PROG_CRYPT_KEY=""
fi

# The RESTORE_ARCHIVES array contains the restore input files.
# If it is not set, RESTORE_ARCHIVES is only one element which is the backup archive:
test "$RESTORE_ARCHIVES" || RESTORE_ARCHIVES=( "$backuparchive" )

# In case of 'tar' the backup restore prog needs to be feed by another program
# if the backup is splitted and then restore input is not a file but a FIFO
# i.e. RESTORE_ARCHIVES is then only one element which is the FIFO
# In this case launch another subshell that runs the feeder program:
if test -f $TMP_DIR/backup.splitted ; then
    # for multiple ISOs
    RESTORE_ARCHIVES=( "$FIFO" )
    (   # Give the subsequent subshell that runs the backup restore prog a good chance to start working:
        sleep 1
        Print ""
        while read backup_splitted_line ; do
            # The lines in backup.splitted are like
            #   backup.tar.gz.00 878706688 RELAXRECOVER
            #   backup.tar.gz.01 878706688 RELAXRECOVER_01
            #   backup.tar.gz.02 758343480 RELAXRECOVER_02
            # The first word is name, the second a size, the last one is the label/vol_name:
            name=${backup_splitted_line%% *}
            vol_name=${backup_splitted_line##* }
            backup_file_path="$opath/$name"
            # Clean up a possibly existing ProgressInfo message before printing a LogPrint message:
            ProgressInfo ""
            LogPrint "Preparing to restore $name ..."
            # Wait for the right labelled medium to appear:
            touch $TMP_DIR/wait_dvd
            while ! test -f "$backup_file_path" ; do
                umount "$BUILD_DIR/outputfs"
                cdrom_devnames=$( cat /proc/sys/dev/cdrom/info | grep -i "drive name:" | awk '{print $3 " " $4}' )
                ProgressInfo "Insert medium labelled $vol_name (containing $name) in a CD-ROM drive ($cdrom_devnames) ..."
                sleep 3
                for cdrom_dev in $cdrom_devnames ; do
                    cdrom_device="/dev/$cdrom_dev"
                    ProgressInfo "Autodetecting medium in $cdrom_device ..."
                    if blkid $cdrom_device | grep -q "$vol_name" ; then
                        ProgressInfo ""
                        LogPrint "Medium labelled $vol_name detected in $cdrom_device ..."
                        mount $cdrom_device "$BUILD_DIR/outputfs" || Error "Failed to mount $cdrom_device"
                        break
                    else
                        sleep 2
                        ProgressInfo "No medium labelled $vol_name detected in $cdrom_device ..."
                        sleep 2
                    fi
                done
            done
            # The right labelled medium has appeared:
            if test -f "$backup_file_path" ; then
                if is_true "$BACKUP_INTEGRITY_CHECK" && test -f "$TMP_DIR/backup.md5" ; then
                    ProgressInfo ""
                    LogPrint "Checking backup integrity for $name ..."
                    ( cd $( dirname $backuparchive ) && grep $name "$TMP_DIR/backup.md5" | md5sum -c )
                    ret=$?
                    if [[ $ret -ne 0 ]] ; then
                        Error "Integrity check failed. Restore aborted because BACKUP_INTEGRITY_CHECK is enabled."
                        return
                    fi
                fi
                rm -f $TMP_DIR/wait_dvd
                ProgressInfo ""
                LogPrint "Processing $name ..."
                # The actual feeder program:
                dd if="$backup_file_path" of="$FIFO"
            else
                StopIfError "$name could not be found on the $vol_name medium!"
            fi
        done < $TMP_DIR/backup.splitted
        # Clean up:
        kill -9 $( cat "$TMP_DIR/cat_pid" )
        rm -f $TMP_DIR/cat_pid $TMP_DIR/backup.splitted $TMP_DIR/backup.md5
    ) &
    BackupRestoreFeederPID=$!
    Log "Launched backup restore feeder subshell (PID=$BackupRestoreFeederPID)"
fi

# The actual restoring:
for restoreinput in "${RESTORE_ARCHIVES[@]}" ; do
    LogPrint "Restoring from '$restoreinput'..."
    # Launch a subshell that runs the backup restore prog:
    (   case "$BACKUP_PROG" in
            (tar)
                # Add the --selinux option to be safe with SELinux context restoration
                if ! is_true "$BACKUP_SELINUX_DISABLE" ; then
                    if tar --usage | grep -q selinux ; then
                        BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --selinux"
                    fi
                fi
                if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
                    BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --exclude-from=$TMP_DIR/restore-exclude-list.txt "
                fi
                Log dd if=$restoreinput \| $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY \| $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $TARGET_FS_ROOT/ -x -f -
                dd if=$restoreinput | $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | $BACKUP_PROG --block-number --totals --verbose $BACKUP_PROG_OPTIONS "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $TARGET_FS_ROOT/ -x -f -
                ;;
            (rsync)
                if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
                    BACKUP_RSYNC_OPTIONS=( "${BACKUP_RSYNC_OPTIONS[@]}" --exclude-from=$TMP_DIR/restore-exclude-list.txt )
                fi
                Log $BACKUP_PROG $v "${BACKUP_RSYNC_OPTIONS[@]}" "$restoreinput"/ $TARGET_FS_ROOT/
                $BACKUP_PROG $v "${BACKUP_RSYNC_OPTIONS[@]}" "$restoreinput"/ $TARGET_FS_ROOT/
                ;;
            (*)
                Log "Using unsupported backup restore program '$BACKUP_PROG'"
                $BACKUP_PROG "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" $BACKUP_PROG_OPTIONS_RESTORE_ARCHIVE $TARGET_FS_ROOT $BACKUP_PROG_OPTIONS $restoreinput
                ;;
        esac >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log"
        # Important trick: The backup prog is the last command in each case entry and the case..esac is the last command
        # in the (..) subshell. As a result the return code of the subshell is the return code of the backup prog.
    ) &
    BackupPID=$!
    Log "Launched backup restore subshell (PID=$BackupPID)"

    starttime=$SECONDS

    # make sure that we don't fall for an old size info
    unset size

    # While the backup restore runs in a sub-process, display some progress information to the user.
    # ProgressInfo texts have a space at the end to get the 'OK' from ProgressStop shown separated.
    test "$PROGRESS_WAIT_SECONDS" || PROGRESS_WAIT_SECONDS=1
    ProgressStart "Restoring... "
    case "$BACKUP_PROG" in
        (tar)
            # Sleep one second to be on the safe side before testing that the backup sub-process is running and
            # avoid "kill: (BackupPID) - No such process" output when the backup sub-process has finished:
            while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
                blocks="$( tail -1 "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log" | awk 'BEGIN { FS="[ :]" } /^block [0-9]+: / { print $2 }' )"
                size="$((blocks*512))"
                if [ -f ${TMP_DIR}/wait_dvd ] ; then
                    starttime=$((starttime+1))
                else
                    restored_size_MiB=$((size/1024/1024))
                    restored_avg_KiB_per_sec=$((size/1024/(SECONDS-starttime)))
                    ProgressInfo "Restored $restored_size_MiB MiB [avg $restored_avg_KiB_per_sec KiB/sec] "
                fi
            done
            ;;
        (*)
            # Display some rather meaningless info to shows at least that restoring is still going on:
            while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
                restore_seconds="$((SECONDS-starttime))"
                ProgressInfo "Restoring for $restore_seconds seconds... "
            done
            ;;
    esac
    ProgressStop

    transfertime="$((SECONDS-starttime))"

    # Get the return code from the backup restore subshell which is the return code of the backup prog (see "Important trick" above).
    # In POSIX shells wait returns the exit code of the job even if it had already terminated when wait was started,
    # see http://pubs.opengroup.org/onlinepubs/9699919799/utilities/wait.html that reads:
    # "This volume of POSIX.1-2008 requires the implementation to keep the status
    #  of terminated jobs available until the status is requested".
    # Avoid messages like "[1]+ Done..." or "[1]+ Terminated...".
    wait $BackupPID 2>/dev/null
    backup_prog_return_code=$?
    if test "0" != "$backup_prog_return_code" ; then
        LogPrint "Backup restore program '$BACKUP_PROG' failed with return code '$backup_prog_return_code'. Check '$LOGFILE' and the restored system."
        is_true "$BACKUP_INTEGRITY_CHECK" && Error "Integrity check failed. Restore aborted because BACKUP_INTEGRITY_CHECK is enabled."
    fi

    # TODO if size is not given then calculate it from backuparchive_size
    tar_message="$(tac $LOGFILE | grep -m1 '^Total bytes written: ')"
    if test "$backup_prog_return_code" = "0" -a "$tar_message" ; then
        LogPrint "$tar_message in $transfertime seconds."
    elif [ "$size" ] ; then
        restored_size_MiB=$((size/1024/1024))
        restored_avg_KiB_per_sec=$((size/1024/transfertime))
        LogPrint "Restored $restored_size_MiB MiB in $((transfertime)) seconds [avg $restored_avg_KiB_per_sec KiB/sec]"
    fi

done
LogPrint "Restoring finished."

