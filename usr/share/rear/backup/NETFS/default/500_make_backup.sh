#
# 500_make_backup.sh
#

function set_tar_features () {
    # Default tar options
    TAR_OPTIONS=
    # Test for features in tar
    # true if at supports the --warning option (v1.23+)
    FEATURE_TAR_WARNINGS=
    local tar_version=$( get_version tar --version )
    if version_newer "$tar_version" 1.23 ; then
        FEATURE_TAR_WARNINGS="y"
        TAR_OPTIONS+=" --warning=no-xdev"
    fi
    FEATURE_TAR_IS_SET=1
}

local backup_prog_rc

local scheme=$( url_scheme $BACKUP_URL )
local path=$( url_path $BACKUP_URL )
local opath=$( backup_path $scheme $path )
test "$opath" && mkdir $v -p "$opath"

# In any case show an initial basic info what is currently done
# so that it is more clear where subsequent messages belong to:
LogPrint "Making backup (using backup method $BACKUP)"

# Verify that preconditions to make the backup are fulfilled and error out if not:
if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
    # Backup archive encryption is only supported with 'tar':
    test "tar" = "$BACKUP_PROG" || Error "Backup archive encryption is only supported with BACKUP_PROG=tar"
    # Backup archive encryption is impossible without a BACKUP_PROG_CRYPT_KEY value.
    # Avoid that the BACKUP_PROG_CRYPT_KEY value is shown in debugscript mode
    # cf. the comment of the UserInput function in lib/_input-output-functions.sh
    # how to keep things confidential when usr/sbin/rear is run in debugscript mode
    # ('2>>/dev/$SECRET_OUTPUT_DEV' should be sufficient here because 'test' does not output on stdout):
    { test "$BACKUP_PROG_CRYPT_KEY" ; } 2>>/dev/$SECRET_OUTPUT_DEV || Error "BACKUP_PROG_CRYPT_KEY must be set for backup archive encryption"
    LogPrint "Encrypting backup archive with key defined in BACKUP_PROG_CRYPT_KEY"
fi

# Log what is included in the backup and what is excluded from the backup
# cf. backup/NETFS/default/400_create_include_exclude_files.sh
Log "Backup include list (backup-include.txt contents without subsequent duplicates):"
while read -r backup_include_item ; do
    test "$backup_include_item" && Log "  $backup_include_item"
done < <( unique_unsorted $TMP_DIR/backup-include.txt )
Log "Backup exclude list (backup-exclude.txt contents):"
while read -r backup_exclude_item ; do
    test "$backup_exclude_item" && Log "  $backup_exclude_item"
done < $TMP_DIR/backup-exclude.txt

# Check if the backup needs to be splitted or not (on multiple ISOs).
# Dummy split command when the backup is not splitted (the default case).
# Let 'dd' read and write up to 1M=1024*1024 bytes at a time to speed up things
# for example from only 500KiB/s (with the 'dd' default of 512 bytes)
# via a 100MBit network connection to about its full capacity
# cf. https://github.com/rear/rear/issues/2369
SPLIT_COMMAND="dd of=$backuparchive bs=1M"
if test $ISO_MAX_SIZE ; then
    is_positive_integer $ISO_MAX_SIZE || Error "ISO_MAX_SIZE must be a positive integer value"
    # Tell the user when ISO_MAX_SIZE is less than 600MiB because then things will likely not work
    # because a usual recovery system with FIRMWARE_FILES is more than 300MiB
    # cf. https://github.com/rear/rear/pull/2347#issuecomment-602812451
    # so that there is less than 300MiB left for the actual backup split chunk size:
    test $ISO_MAX_SIZE -ge 600 || LogPrintError "ISO_MAX_SIZE should be at least 600 MiB"
    # Computation of the actual backup split chunk size
    # by subtracting the recovery system file sizes (kernel, initrd, ISOLINUX files, UEFI files if used)
    # from the ISO_MAX_SIZE value, see the ISO_MAX_SIZE explanation in default.conf why that is done.
    # Size of the recovery system initrd in bytes:
    INITRD_BYTES=$( stat -c '%s' $TMP_DIR/$REAR_INITRD_FILENAME )
    is_positive_integer $INITRD_BYTES || Error "Cannot determine size of the recovery system initrd $TMP_DIR/$REAR_INITRD_FILENAME"
    # Size of the recovery system initrd in MiB + 1MiB to be safe against integer (floor) rounding:
    INITRD_SIZE=$(( INITRD_BYTES / 1024 / 1024 + 1 ))
    # Size of the recovery system kernel in bytes:
    KERNEL_BYTES=$( stat -c '%s' $KERNEL_FILE )
    is_positive_integer $KERNEL_BYTES || Error "Cannot determine size of the recovery system kernel $KERNEL_FILE"
    # Size of the recovery system kernel in MiB + 1MiB to be safe against integer (floor) rounding:
    KERNEL_SIZE=$(( KERNEL_BYTES / 1024 / 1024 + 1 ))
    # We assume 15MiB is sufficient size for the ISOLINUX bootloader files:
    ISOLINUX_SIZE=15
    # We assume 30MiB is sufficient size for additional UEFI bootloader files:
    UEFI_SIZE=0
    is_true $USING_UEFI_BOOTLOADER && UEFI_SIZE=30
    # Size of the recovery system and its bootloader in MiB:
    RECOVERY_SYSTEM_SIZE=$(( INITRD_SIZE + KERNEL_SIZE + ISOLINUX_SIZE + UEFI_SIZE ))
    # Tell the user when the recovery system plus ISO bootloader is extraordinarily large because that may indicate a problem elsewehre:
    test $RECOVERY_SYSTEM_SIZE -gt 1000 && LogPrintError "Extraordinarily large recovery system plus ISO bootloader $RECOVERY_SYSTEM_SIZE MiB"
    # Size of the actual backup split chunk size in MiB:
    BACKUP_SPLIT_CHUNK_SIZE=$(( ISO_MAX_SIZE - RECOVERY_SYSTEM_SIZE ))
    # When the actual backup split chunk size is less than 100MiB we consider it too small to be useful in practice:
    test $BACKUP_SPLIT_CHUNK_SIZE -ge 100 || Error "Backup split chunk size $BACKUP_SPLIT_CHUNK_SIZE less than 100 MiB (ISO_MAX_SIZE too small?)"
    # Split the 'tar' backup (at stdin) in chunks of BACKUP_SPLIT_CHUNK_SIZE MiB using 'backup.tar.gz.' as prefix with numeric suffixes:
    LogPrint "Backup gets split in chunks of $BACKUP_SPLIT_CHUNK_SIZE MiB (ISO_MAX_SIZE $ISO_MAX_SIZE minus recovery system size $RECOVERY_SYSTEM_SIZE)"
    SPLIT_COMMAND="split -d -b ${BACKUP_SPLIT_CHUNK_SIZE}m - ${backuparchive}."
fi

# Used by "tar" method to record which pipe command failed
FAILING_BACKUP_PROG_FILE="$TMP_DIR/failing_backup_prog"
FAILING_BACKUP_PROG_RC_FILE="$TMP_DIR/failing_backup_prog_rc"

# Do not show the BACKUP_PROG_CRYPT_KEY value in a log file
# where BACKUP_PROG_CRYPT_KEY is only used if BACKUP_PROG_CRYPT_ENABLED is true
# therefore 'Log ... BACKUP_PROG_CRYPT_KEY ...' is used (and not '$BACKUP_PROG_CRYPT_KEY')
# but '$BACKUP_PROG_CRYPT_KEY' must be used in the actual command call which means
# the BACKUP_PROG_CRYPT_KEY value would appear in the log when rear is run in debugscript mode
# so that stderr of the confidential command is redirected to /dev/null
# cf. the comment of the UserInput function in lib/_input-output-functions.sh
# how to keep things confidential when rear is run in debugscript mode
# because it is more important to not leak out user secrets into a log file
# than having stderr error messages when a confidential command fails
# cf. https://github.com/rear/rear/issues/2155
LogPrint "Creating $BACKUP_PROG archive '$backuparchive'"
ProgressStart "Preparing archive operation"
# Begin backup subshell:
(
case "$(basename ${BACKUP_PROG})" in
    # tar compatible programs here
    (tar)
        set_tar_features

        if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
            Log $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose \
                --no-wildcards-match-slash --one-file-system \
                --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}" \
                $BACKUP_PROG_CREATE_NEWER_OPTIONS \
                ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS} "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" \
                -X $TMP_DIR/backup-exclude.txt -C / -c -f - \
                $(unique_unsorted $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE \| $BACKUP_PROG_CRYPT_OPTIONS BACKUP_PROG_CRYPT_KEY \| $SPLIT_COMMAND
        else
            Log $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose \
                --no-wildcards-match-slash --one-file-system \
                --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}" \
                $BACKUP_PROG_CREATE_NEWER_OPTIONS \
                ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS} "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" \
                -X $TMP_DIR/backup-exclude.txt -C / -c -f - \
                $(unique_unsorted $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE \| $SPLIT_COMMAND
        fi

        if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
            backup_prog_shortnames=(
                "$(basename $(echo "$BACKUP_PROG" | awk '{ print $1 }'))"
                "$(basename $(echo "$BACKUP_PROG_CRYPT_OPTIONS" | awk '{ print $1 }'))"
                "$(basename $(echo "$SPLIT_COMMAND" | awk '{ print $1 }'))"
            )
            $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose                   \
                --no-wildcards-match-slash --one-file-system                                       \
                --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}"                                   \
                $BACKUP_PROG_CREATE_NEWER_OPTIONS                                                  \
                ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS}                                      \
                "${BACKUP_PROG_COMPRESS_OPTIONS[@]}"                                               \
                -X $TMP_DIR/backup-exclude.txt -C / -c -f -                                        \
                $(unique_unsorted $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE |                  \
            { $BACKUP_PROG_CRYPT_OPTIONS "$BACKUP_PROG_CRYPT_KEY" ; } 2>>/dev/$SECRET_OUTPUT_DEV | \
            $SPLIT_COMMAND
            pipes_rc=( ${PIPESTATUS[@]} )
        else
            backup_prog_shortnames=(
                "$(basename $(echo "$BACKUP_PROG" | awk '{ print $1 }'))"
                "$(basename $(echo "$SPLIT_COMMAND" | awk '{ print $1 }'))"
            )
            $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose  \
                --no-wildcards-match-slash --one-file-system                      \
                --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}"                  \
                $BACKUP_PROG_CREATE_NEWER_OPTIONS                                 \
                ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS}                     \
                "${BACKUP_PROG_COMPRESS_OPTIONS[@]}"                              \
                -X $TMP_DIR/backup-exclude.txt -C / -c -f -                       \
                $(unique_unsorted $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE | \
            $SPLIT_COMMAND
            pipes_rc=( ${PIPESTATUS[@]} )
        fi

        # Variable used to record the short name of piped commands in case of
        # error, e.g. ( "tar" "cat" "dd" ) in case of unencrypted and unsplit backup.
        for index in "${!backup_prog_shortnames[@]}" ; do
            [ -n "${backup_prog_shortnames[$index]}" ] || BugError "No computed shortname for pipe component $index"
        done

        # Ensure that the numbers of pipe components and return codes match.
        [ ${#backup_prog_shortnames[@]} -eq ${#pipes_rc[@]} ] || BugError "Mismatching numbers of pipe components and return codes"

        # Exit code logic:
        # * don't return rc=1 unless from tar (exit code 1 is reserved for "tar" warning about modified files)
        # * process exit code in pipe's reverse order
        #   - if last command failed (e.g. "dd"), return an error
        #   - otherwise if previous command failed (e.g. "encrypt"), return an error
        #   ...
        #   - otherwise return "tar" exit code
        # When an error occurs, record the program name in $FAILING_BACKUP_PROG_FILE
        # and real exit code in $FAILING_BACKUP_PROG_RC_FILE.
        let index=${#pipes_rc[@]}-1
        while [ $index -ge 0 ] ; do
            rc=${pipes_rc[$index]}
            if [ $rc -ne 0 ] ; then
                echo "${backup_prog_shortnames[$index]}" > $FAILING_BACKUP_PROG_FILE
                echo "$rc" > $FAILING_BACKUP_PROG_RC_FILE
                if [ $rc -eq 1 ] && [ "${backup_prog_shortnames[$index]}" != "tar" ] ; then
                    rc=2
                fi
                # Exit the backup subshell with non-zero exit code:
                exit $rc
            fi
            # This pipe command succeeded, check the previous one
            let index--
        done
        # Success - exit the backup subshell with zero exit code:
        exit 0
    ;;
    (rsync)
        # make sure that the target is a directory
        mkdir -p $v "$backuparchive" >&2
        Log $BACKUP_PROG --verbose "${BACKUP_RSYNC_OPTIONS[@]}" --one-file-system --delete \
            --exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded \
            $(unique_unsorted $TMP_DIR/backup-include.txt) "$backuparchive"
        $BACKUP_PROG --verbose "${BACKUP_RSYNC_OPTIONS[@]}" --one-file-system --delete \
            --exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded \
            $(unique_unsorted $TMP_DIR/backup-include.txt) "$backuparchive" >&2
    ;;
    (*)
        Log "Using unsupported backup program '$BACKUP_PROG'"
        Log $BACKUP_PROG "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" \
            $BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $TMP_DIR/backup-exclude.txt \
            "${BACKUP_PROG_OPTIONS[@]}" $backuparchive \
            $(unique_unsorted $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE > $backuparchive
        $BACKUP_PROG "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" \
            $BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $TMP_DIR/backup-exclude.txt \
            "${BACKUP_PROG_OPTIONS[@]}" $backuparchive \
            $(unique_unsorted $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE > $backuparchive
    ;;
esac 2> "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"
# For the rsync and default case the backup prog is the last in the case entry
# and the case .. esac is the last command in the backup subshell.
# As a result the return code of the backup subshell is the return code of the backup prog.
# For the tar case (where tar is not the last program) special exit code logic is done.
) &
BackupPID=$!
# End backup subshell.

starttime=$SECONDS
# Give the backup software a good chance to start working:
sleep 1

# return disk usage in bytes
function get_disk_used() {
    let "$(stat -f -c 'used=(%b-%f)*%S' $1)"
    echo $used
}

# While the backup runs in a subshell, display some progress information to the user.
# ProgressInfo texts have a space at the end to get the 'OK' from ProgressStop shown separated.
test "$PROGRESS_WAIT_SECONDS" || PROGRESS_WAIT_SECONDS=1
case "$( basename $BACKUP_PROG )" in
    (tar)
        while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null; do
            #blocks="$(stat -c %b ${backuparchive})"
            #size="$((blocks*512))"
            size="$(stat -c %s ${backuparchive}* | awk '{s+=$1} END {print s}')"
            ProgressInfo "Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec] "
        done
        ;;
    (rsync)
        # since we do not want to do a $(du -s) run every second we count disk usage instead
        # this obviously leads to wrong results in case something else is writing to the same
        # disk at the same time as is very likely with a networked file system. For local disks
        # this should be good enough and in any case this is only some eye candy.
        # TODO: Find a fast way to count the actual transfer data, preferrable getting the info from rsync.
        let old_disk_used="$(get_disk_used "$backuparchive")"
        while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null; do
            let disk_used="$(get_disk_used "$backuparchive")" size=disk_used-old_disk_used
            ProgressInfo "Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec] "
        done
        ;;
    (*)
        while sleep $PROGRESS_WAIT_SECONDS ; kill -0 $BackupPID 2>/dev/null; do
            size="$(stat -c "%s" "$backuparchive")" || {
                kill -9 $BackupPID
                ProgressError
                Error "$(basename $BACKUP_PROG) failed to create the archive file"
            }
            ProgressInfo "Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec] "
        done
        ;;
esac
ProgressStop
transfertime="$((SECONDS-starttime))"

# harvest return code from background job. The kill -0 $BackupPID loop above should
# have made sure that this wait won't do any real "waiting" :-)
wait $BackupPID
backup_prog_rc=$?

if [[ $BACKUP_INTEGRITY_CHECK =~ ^[yY1] && "$(basename ${BACKUP_PROG})" = "tar" ]] ; then
    (cd $(dirname $backuparchive) && md5sum $(basename $backuparchive) > ${backuparchive}.md5 || md5sum $(basename $backuparchive).?? > ${backuparchive}.md5)
fi

# TODO: Why do we sleep here after 'wait $BackupPID'?
sleep 1

# Everyone should see this warning, even if not verbose:
case "$(basename $BACKUP_PROG)" in
    (tar)
        if (( $backup_prog_rc != 0 )); then
            prog="$(cat $FAILING_BACKUP_PROG_FILE)"
            # Suppress purely informational tar messages from output like
            #   tar: Removing leading / from member names
            #   tar: Removing leading / from hard link targets
            #   tar: /var/spool/postfix/private/discard: socket ignored
            # but keep actual tar error or warning messages like
            #    tar: /etc/grub.d/README: file changed as we read it
            # and show only messages that are prefixed with "$prog:" (like 'tar:' or 'dd:')
            # which works when 'tar' or 'dd' fail but falsely suppresses messages from 'openssl'
            # FIXME see https://github.com/rear/rear/pull/2466#discussion_r466347471
            if (( $backup_prog_rc == 1 )); then
                LogUserOutput "WARNING: $prog ended with return code 1 and below output (last 5 lines):
  ---snip---
$( sed -n -e '/^tar: .*\(socket ignored\|Removing leading\)/d;/^'"$prog"':/s/^/  /p' "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" | tail -n5 )
  ----------
This means that files have been modified during the archiving
process. As a result the backup may not be completely consistent
or may not be a perfect copy of the system. Relax-and-Recover
will continue, however it is highly advisable to verify the
backup in order to be sure to safely recover this system.
"
            else
                rc=$(cat $FAILING_BACKUP_PROG_RC_FILE)
                Error "$prog failed with return code $rc and below output (last 5 lines):
  ---snip---
$( sed -n -e '/^tar: .*\(socket ignored\|Removing leading\)/d;/^'"$prog"':/s/^/  /p' "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" | tail -n5 )
  ----------
This means that the archiving process ended prematurely, or did
not even start. As a result it is unlikely you can recover this
system properly. Relax-and-Recover is therefore aborting execution.
"
            fi
        fi
        ;;
    (*)
        if (( $backup_prog_rc > 0 )) ; then
            Error "$(basename $BACKUP_PROG) failed with return code $backup_prog_rc

This means that the archiving process ended prematurely, or did
not even start. As a result it is unlikely you can recover this
system properly. Relax-and-Recover is therefore aborting execution.
"
        fi
        ;;
esac

tar_message="$(tac $RUNTIME_LOGFILE | grep -m1 '^Total bytes written: ')"
if [ $backup_prog_rc -eq 0 -a "$tar_message" ] ; then
    LogPrint "$tar_message in $transfertime seconds."
elif [ "$size" ]; then
    LogPrint "Archived $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi

### Copy progress log to backup media
cp $v "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" "${opath}/${BACKUP_PROG_ARCHIVE}.log" >&2

# vim: set et ts=4 sw=4:
