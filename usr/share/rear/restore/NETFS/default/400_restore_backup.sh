#
# 400_restore_backup.sh
#

local scheme=$( url_scheme $BACKUP_URL )
local path=$( url_path $BACKUP_URL )
local opath=$( backup_path $scheme $path )

# Create backup restore log file name:
local backup_restore_log_dir="$VAR_DIR/restore"
mkdir -p $backup_restore_log_dir
local backup_restore_log_file=""
local backup_restore_log_prefix=$WORKFLOW
local backup_restore_log_suffix="restore.log"
# E.g. when "rear -C 'general.conf /path/to/special.conf' recover" was called CONFIG_APPEND_FILES is "general.conf /path/to/special.conf"
# so that in particular '/' characters must be replaced in the backup restore log file (by a colon) and then
# the backup restore log file name will be like .../restore/recover.generalconf_:path:to:specialconf.backup.tar.gz.1234.restore.log
# It does not work with $( tr -d -c '[:alnum:]/[:space:]' <<<"$CONFIG_APPEND_FILES" | tr -s '/[:space:]' ':_' )
# because the <<<"$CONFIG_APPEND_FILES" results a trailing newline that becomes a trailing '_' character so that
# echo -n $CONFIG_APPEND_FILES (without double quotes) is used to avoid leading and trailing spaces and newlines:
test "$CONFIG_APPEND_FILES" && backup_restore_log_prefix=$backup_restore_log_prefix.$( echo -n $CONFIG_APPEND_FILES | tr -d -c '[:alnum:]/[:space:]' | tr -s '/[:space:]' ':_' )
local restore_input_basename=""

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
            #   backup.tar.gz.00 878706688 REAR-ISO
            #   backup.tar.gz.01 878706688 REAR-ISO_01
            #   backup.tar.gz.02 758343480 REAR-ISO_02
            # The first word is backup file name, the second a size, the last one is the label/vol_name:
            backup_file_name=${backup_splitted_line%% *}
            vol_name=${backup_splitted_line##* }
            backup_file_path="$opath/$backup_file_name"
            # Clean up a possibly existing ProgressInfo message before printing a LogPrint message:
            ProgressInfo ""
            LogPrint "Preparing to restore $backup_file_name ..."
            # Wait for the right labelled medium to appear:
            touch $waiting_for_medium_flag_file
            while ! test -f "$backup_file_path" ; do
                if mountpoint -q "$BUILD_DIR/outputfs" ; then
                    umount "$BUILD_DIR/outputfs" || LogPrintError "Could not umount what is mounted at $BUILD_DIR/outputfs"
                fi
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
                        Error "Integrity check failed, restore aborted because BACKUP_INTEGRITY_CHECK is enabled"
                        return
                    fi
                fi
                rm -f $waiting_for_medium_flag_file
                ProgressInfo ""
                LogPrint "Processing $backup_file_name ..."
                # The actual feeder program:
                # Let 'dd' read and write up to 1M=1024*1024 bytes at a time to speed up things
                # cf. https://github.com/rear/rear/issues/2369 and https://github.com/rear/rear/issues/2458
                dd if="$backup_file_path" of="$FIFO" bs=1M
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
    # Create backup restore log file name (a different one for each restore_input).
    # Each restore_input is a path like '/var/tmp/rear.XXXX/outputfs/f121/backup.tar.gz':
    restore_input_basename=$( basename $restore_input )
    backup_restore_log_file=$backup_restore_log_dir/$backup_restore_log_prefix.$restore_input_basename.$MASTER_PID.$backup_restore_log_suffix
    cat /dev/null >$backup_restore_log_file
    LogPrint "Restoring from '$restore_input' (restore log in $backup_restore_log_file) ..."
    # Launch a subshell that runs the backup restore program.
    # Important trick: The backup restore program is the last command in each case entry
    # and the case...esac is the last command in the (...) subshell so that
    # the exit code of the subshell is the exit code of the backup restore program.
    # Both stdout and stderr are redirected into the backup restore log file
    # to have all backup restore program messages in one same log file and
    # in the right ordering because with 2>&1 both streams are correctly merged
    # cf. https://github.com/rear/rear/issues/885#issuecomment-310082587
    # which also means that in '-D' debugscript mode the 'set -x' messages of the case...esac
    # appear in the backup restore log file which is perfectly fine because in the normal log file
    # the above LogPrint tells via "restore log in $backup_restore_log_file" where to look and
    # it is helpful for debugging to also have the related 'set -x' messages in the same log file.
    # To be more on the safe side append to the log file '>>' instead of plain writing to it '>'
    # because when a program (bash in this case) is plain writing to the log file it can overwrite
    # output of a possibly simultaneously running process that likes to append to the log file
    # (e.g. when background processes run that also uses the log file for logging)
    # cf. https://github.com/rear/rear/issues/885#issuecomment-310308763
    # Do not show the BACKUP_PROG_CRYPT_KEY value in a log file
    # where BACKUP_PROG_CRYPT_KEY is only used if BACKUP_PROG_CRYPT_ENABLED is true
    # therefore 'Log ... BACKUP_PROG_CRYPT_KEY ...' is used (and not '$BACKUP_PROG_CRYPT_KEY')
    # but '$BACKUP_PROG_CRYPT_KEY' must be used in the actual command call which means
    # the BACKUP_PROG_CRYPT_KEY value would appear in the log when rear is run in debugscript mode
    # so that stderr of the confidential command is redirected to SECRET_OUTPUT_DEV (normally /dev/null)
    # cf. the comment of the UserInput function in lib/_input-output-functions.sh
    # how to keep things confidential when rear is run in debugscript mode
    # because it is more important to not leak out user secrets into a log file
    # than having stderr error messages when a confidential command fails
    # cf. https://github.com/rear/rear/issues/2155
    (   case "$BACKUP_PROG" in
            (tar)
                if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
                    BACKUP_PROG_OPTIONS+=( "--exclude-from=$TMP_DIR/restore-exclude-list.txt" )
                fi
                # Let 'dd' read and write up to 1M=1024*1024 bytes at a time to speed up things
                # cf. https://github.com/rear/rear/issues/2369 and https://github.com/rear/rear/issues/2458
                if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then 
                    Log "dd if=$restore_input bs=1M | $BACKUP_PROG_DECRYPT_OPTIONS BACKUP_PROG_CRYPT_KEY | $BACKUP_PROG --block-number --totals --verbose ${BACKUP_PROG_OPTIONS[@]} ${BACKUP_PROG_COMPRESS_OPTIONS[@]} -C $TARGET_FS_ROOT/ -x -f -"
                    dd if=$restore_input bs=1M | { $BACKUP_PROG_DECRYPT_OPTIONS "$BACKUP_PROG_CRYPT_KEY" ; } 2>>/dev/$SECRET_OUTPUT_DEV | $BACKUP_PROG --block-number --totals --verbose "${BACKUP_PROG_OPTIONS[@]}" "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $TARGET_FS_ROOT/ -x -f -

                else
                    Log "dd if=$restore_input bs=1M | $BACKUP_PROG --block-number --totals --verbose ${BACKUP_PROG_OPTIONS[@]} ${BACKUP_PROG_COMPRESS_OPTIONS[@]} -C $TARGET_FS_ROOT/ -x -f -"

                    dd if=$restore_input bs=1M | $BACKUP_PROG --block-number --totals --verbose "${BACKUP_PROG_OPTIONS[@]}" "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" -C $TARGET_FS_ROOT/ -x -f -
                fi
                ;;
            (rsync)
                if [ -s $TMP_DIR/restore-exclude-list.txt ] ; then
                    BACKUP_RSYNC_OPTIONS+=( --exclude-from=$TMP_DIR/restore-exclude-list.txt )
                fi
                Log $BACKUP_PROG $v "${BACKUP_RSYNC_OPTIONS[@]}" "$restore_input"/ $TARGET_FS_ROOT/
                $BACKUP_PROG $v "${BACKUP_RSYNC_OPTIONS[@]}" "$restore_input"/ $TARGET_FS_ROOT/
                ;;
            (*)
                Log "Using unsupported backup restore program '$BACKUP_PROG'"
                $BACKUP_PROG "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" $BACKUP_PROG_OPTIONS_RESTORE_ARCHIVE $TARGET_FS_ROOT "${BACKUP_PROG_OPTIONS[@]}" $restore_input
                ;;
        esac 1>>$backup_restore_log_file 2>&1
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
                    # Example how the 'tar --verbose' messages in $backup_restore_log_file look like
                    #   block 3: ./
                    #   block 6: dev/
                    #   block 9: home/
                    #   ...
                    #   block 5882676: lib64/libcom_err.so.2
                    #   block 5882679: root/rear/var/log/rear/rear-f79.28698.log
                    #   block 5882679: ** Block of NULs **
                    # cf. https://github.com/rear/rear/issues/1116#issuecomment-267065150
                    # Use an array to easily separate the parts (i.e. each message word is an array member):
                    latest_tar_restore_message=( $( tail -n1 $backup_restore_log_file ) )
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
                latest_tar_restore_message=( $( tail -n1 $backup_restore_log_file ) )
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
        LogPrint "Backup restore program $BACKUP_PROG failed with exit code $backup_prog_exit_code, check $RUNTIME_LOGFILE and $backup_restore_log_file and the restored system"
        is_true "$BACKUP_INTEGRITY_CHECK" && Error "Integrity check failed, restore aborted because BACKUP_INTEGRITY_CHECK is enabled"
    fi

done
LogPrint "Restoring finished (verify backup restore log messages in $backup_restore_log_file)"

