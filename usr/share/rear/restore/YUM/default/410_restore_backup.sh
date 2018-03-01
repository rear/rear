# 400_restore_backup.sh
#

if ! is_true "$YUM_BACKUP_FILES" ; then
        LogPrint "Backup of system files not created ... skipping restore (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"
        return
fi
LogPrint "Restoring system files (YUM_BACKUP_FILES=$YUM_BACKUP_FILES)"

# Try to care about possible errors
# see https://github.com/rear/rear/wiki/Coding-Style
set -e -u -o pipefail

local scheme=$(url_scheme $BACKUP_URL)
local path=$(url_path $BACKUP_URL)
local opath=$(backup_path $scheme $path)

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
waiting_for_medium_flag_file=$TMP_DIR/waiting_for_restore_medium
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
            # The first word is backup file name, the second a size, the last one is the label/vol_name:
            backup_file_name="${backup_splitted_line%% *}"
            vol_name="${backup_splitted_line##* }"
            backup_file_path="$opath/$backup_file_name"
            # Clean up a possibly existing ProgressInfo message before printing a LogPrint message:
            ProgressInfo ""
            LogPrint "Preparing to restore $backup_file_name ..."
            # Wait for the right labelled medium to appear:
            touch $waiting_for_medium_flag_file
            while ! test -f "$backup_file_path" ; do
                umount "$BUILD_DIR/outputfs"
                cdrom_drive_names=$( cat /proc/sys/dev/cdrom/info | grep -i "drive name:" | awk '{print $3 " " $4}' )
                ProgressInfo "Insert medium labelled $vol_name (containing $backup_file_name) in a CD-ROM drive ($cdrom_drive_names) ..."
                sleep 3
                for cdrom_dev in $cdrom_drive_names ; do
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
                    LogPrint "Checking backup integrity for $backup_file_name ..."
                    ( cd $( dirname $backuparchive ) && grep $backup_file_name "$TMP_DIR/backup.md5" | md5sum -c )
                    ret=$?
                    if [[ $ret -ne 0 ]] ; then
                        Error "Integrity check failed. Restore aborted because BACKUP_INTEGRITY_CHECK is enabled."
                        return
                    fi
                fi
                rm -f $waiting_for_medium_flag_file
                ProgressInfo ""
                LogPrint "Processing $backup_file_name ..."
                # The actual feeder program:
                dd if="$backup_file_path" of="$FIFO"
            else
                StopIfError "$backup_file_name could not be found on the $vol_name medium!"
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
for restore_input in "${RESTORE_ARCHIVES[@]}" ; do
    LogPrint "Restoring from '$restore_input'..."
    # Launch a subshell that runs the backup restore prog:
    (   case "$BACKUP_PROG" in
            (tar)
                # Add the --selinux option to be safe with SELinux context restoration
                if ! is_true "$BACKUP_SELINUX_DISABLE" ; then
                    if tar --usage | grep -q selinux ; then
                        BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --selinux"
                    fi
                    if tar --usage | grep -wq -- --xattrs ; then
                        BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --xattrs"
                    fi
                    if tar --usage | grep -wq -- --xattrs-include ; then
                        BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --xattrs-include=\"*.*\""
                    fi
                fi
                if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
		    LogPrint "Copying restore exlusion file from $TMP_DIR/restore-exclude-list.txt to $TARGET_FS_ROOT/tmp"
                    cp -a $TMP_DIR/restore-exclude-list.txt $TARGET_FS_ROOT/tmp
                    BACKUP_PROG_OPTIONS="$BACKUP_PROG_OPTIONS --exclude-from=/tmp/restore-exclude-list.txt "
                fi
                Log dd if=$restore_input \| $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY \| chroot $TARGET_FS_ROOT/ $BACKUP_PROG --acls --preserve-permissions --same-owner --block-number --totals --verbose $BACKUP_PROG_OPTIONS "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C / -x -f -
                dd if=$restore_input | $BACKUP_PROG_DECRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | chroot $TARGET_FS_ROOT/ $BACKUP_PROG --acls --preserve-permissions --same-owner --block-number --totals --verbose $BACKUP_PROG_OPTIONS "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C / -x -f -
                ;;
            (rsync)
                if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
                    BACKUP_RSYNC_OPTIONS=( "${BACKUP_RSYNC_OPTIONS[@]}" --exclude-from=$TMP_DIR/restore-exclude-list.txt )
                fi
                Log $BACKUP_PROG $v "${BACKUP_RSYNC_OPTIONS[@]}" "$restore_input"/ $TARGET_FS_ROOT/
                $BACKUP_PROG $v "${BACKUP_RSYNC_OPTIONS[@]}" "$restore_input"/ $TARGET_FS_ROOT/
                ;;
            (*)
                Log "Using unsupported backup restore program '$BACKUP_PROG'"
                $BACKUP_PROG "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" $BACKUP_PROG_OPTIONS_RESTORE_ARCHIVE $TARGET_FS_ROOT $BACKUP_PROG_OPTIONS $restore_input
                ;;
        esac >"${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log"
        # Important trick: The backup prog is the last command in each case entry and the case..esac is the last command
        # in the (..) subshell. As a result the exit code of the subshell is the exit code of the backup prog.
    ) &
    BackupPID=$!
    Log "Launched backup restore subshell (PID=$BackupPID)"

    restore_start_time=$SECONDS

    # While the backup restore runs in a sub-process, display some progress information to the user.
    # ProgressInfo texts have a space at the end to get the 'OK' from ProgressStop shown separated.
    test "$PROGRESS_WAIT_SECONDS" || PROGRESS_WAIT_SECONDS=1
    ProgressStart "Backup restore program '$BACKUP_PROG' started in subshell (PID=$BackupPID)"
    case "$BACKUP_PROG" in
        (tar)
            # Sleep one second to be on the safe side before testing that the backup sub-process is running and
            # avoid "kill: (BackupPID) - No such process" output when the backup sub-process has finished:
            previous_tar_restore_blocks=0
            while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
                if test -f $waiting_for_medium_flag_file ; then
                    # While waiting for the right labelled restore medium to appear in the backup restore feeder subshell
                    # advance the restore_start_time by the amount of waiting seconds so that the below calculations of KiB/sec
                    # result correct values (i.e. get the waiting time out of the calculations):
                    restore_start_time=$(( restore_start_time + PROGRESS_WAIT_SECONDS ))
                else
                    # Example how the 'tar --verbose' messages in ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log look like
                    #   block 3: ./
                    #   block 6: dev/
                    #   block 9: home/
                    #   ...
                    #   block 5882676: lib64/libcom_err.so.2
                    #   block 5882679: root/rear/var/log/rear/rear-f79.28698.log
                    #   block 5882679: ** Block of NULs **
                    # cf. https://github.com/rear/rear/issues/1116#issuecomment-267065150
                    # Use an array to easily separate the parts (i.e. each message word is an array member):
                    latest_tar_restore_message=( $( tail -n1 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log ) )
                    # An usual 'tar' restore message looks like 'block 219: etc/fstab'
                    # so that ${latest_tar_restore_message[1]} is '219:' in this example.
                    latest_tar_restore_blocks=$( echo ${latest_tar_restore_message[1]} | tr -c -d '[:digit:]' )
                    test "$latest_tar_restore_blocks" || latest_tar_restore_blocks=0
                    if test "$latest_tar_restore_blocks" -gt "$previous_tar_restore_blocks" ; then
                        previous_tar_restore_blocks=$latest_tar_restore_blocks
                        restored_bytes="$(( latest_tar_restore_blocks * 512 ))"
                        restored_KiB=$(( restored_bytes / 1024 ))
                        restored_MiB=$(( restored_KiB / 1024 ))
                        restore_seconds=$(( SECONDS - restore_start_time ))
                        restored_KiB_per_second=$(( restored_KiB / restore_seconds ))
                        ProgressInfo "Restored $restored_MiB MiB [avg. $restored_KiB_per_second KiB/sec] "
                    else
                        # The last member in the latest_tar_restore_message array is usually the currently restoring filename.
                        # A negative subscript as in ${latest_tar_restore_message[-1]} only works in bash 4.3 and above so that
                        # an expression in the subscript is used as in ${latest_tar_restore_message[${#latest_tar_restore_message[@]}-1]}
                        # see http://unix.stackexchange.com/questions/198787/is-there-a-way-of-reading-the-last-element-of-an-array-with-bash
                        latest_tar_restore_file=${latest_tar_restore_message[ ${#latest_tar_restore_message[@]} - 1 ]}
                        # A valid filename in a 'tar --verbose' message contains usually a '/' (perhaps except files directly in '/'):
                        if [[ $latest_tar_restore_file =~ .*/.* ]] ; then
                            ProgressInfo "Restoring $latest_tar_restore_file "
                        else
                            ProgressInfo "Restoring ${latest_tar_restore_message[@]} "
                        fi
                    fi
                fi
            done
            ;;
        (*)
            # Display some rather meaningless info to shows at least that restoring is still going on:
            while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null ; do
                restore_seconds=$(( SECONDS - restore_start_time ))
                ProgressInfo "Restoring for $restore_seconds seconds... "
            done
            ;;
    esac
    ProgressStop

    restore_seconds=$(( SECONDS - restore_start_time ))

    # Get the exit code from the backup restore subshell which is the exit code of the backup prog (see "Important trick" above).
    # In POSIX shells wait returns the exit code of the job even if it had already terminated when wait was started,
    # see http://pubs.opengroup.org/onlinepubs/9699919799/utilities/wait.html that reads:
    # "This volume of POSIX.1-2008 requires the implementation to keep the status
    #  of terminated jobs available until the status is requested".
    # Avoid messages like "[1]+ Done..." or "[1]+ Terminated...".
    wait $BackupPID 2>/dev/null
    backup_prog_exit_code=$?
    if test "0" = "$backup_prog_exit_code" ; then
        # Final info message (now using LogPrint and not ProgressInfo as above):
        case "$BACKUP_PROG" in
            (tar)
                latest_tar_restore_message=( $( tail -n1 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}-restore.log ) )
                latest_tar_restore_blocks=$( echo ${latest_tar_restore_message[1]} | tr -c -d '[:digit:]' )
                test "$latest_tar_restore_blocks" || latest_tar_restore_blocks=0
                if test "$latest_tar_restore_blocks" -gt "1" ; then
                    restored_bytes="$(( latest_tar_restore_blocks * 512 ))"
                    restored_KiB=$(( restored_bytes / 1024 ))
                    restored_MiB=$(( restored_KiB / 1024 ))
                    restore_seconds=$(( SECONDS - restore_start_time ))
                    restored_KiB_per_second=$(( restored_KiB / restore_seconds ))
                    LogPrint "Restored $restored_MiB MiB in $restore_seconds seconds [avg. $restored_KiB_per_second KiB/sec]"
                else
                    # A 'tar -x --totals' stderr messsage should look like 'Total bytes read: 7924664320 (7.4GiB, 95MiB/s)'
                    # cf. https://www.gnu.org/software/tar/manual/html_section/tar_25.html
                    # in the rear runtime logfile it appears like (without leading blanks):
                    #   3823429+1 records in
                    #   3823429+1 records out
                    #   1957595865 bytes (2.0 GB, 1.8 GiB) copied, 46.5426 s, 42.1 MB/s
                    #   Total bytes read: 3665336320 (3.5GiB, 76MiB/s)
                    tar_totals_messsage="$( tac $RUNTIME_LOGFILE | grep -m1 '^Total bytes read: ' )"
                    if test "$tar_totals_messsage" ; then
                        LogPrint "$tar_totals_messsage"
                    else
                        LogPrint "Backup restore 'tar' finished with zero exit code"
                    fi
                fi
                ;;
            (*)
                LogPrint "Backup restore program '$BACKUP_PROG' finished with zero exit code"
                ;;
        esac
    else
        LogPrint "Backup restore program '$BACKUP_PROG' failed with exit code '$backup_prog_exit_code'. Check '$RUNTIME_LOGFILE' and the restored system."
        is_true "$BACKUP_INTEGRITY_CHECK" && Error "Integrity check failed. Restore aborted because BACKUP_INTEGRITY_CHECK is enabled."
    fi

done
LogPrint "Restoring finished."

# Restore the ReaR default bash flags and options (see usr/sbin/rear):
apply_bash_flags_and_options_commands "$DEFAULT_BASH_FLAGS_AND_OPTIONS_COMMANDS"

