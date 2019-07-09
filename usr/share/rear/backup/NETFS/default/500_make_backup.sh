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
        TAR_OPTIONS="$TAR_OPTIONS --warning=no-xdev"
    fi
    FEATURE_TAR_IS_SET=1
}

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
    # ('2>/dev/null' should be sufficient here because 'test' does not output on stdout):
    { test "$BACKUP_PROG_CRYPT_KEY" ; } 2>/dev/null || Error "BACKUP_PROG_CRYPT_KEY must be set for backup archive encryption"
    LogPrint "Encrypting backup archive with key defined in BACKUP_PROG_CRYPT_KEY"
fi

# Log what is included in the backup and what is excluded from the backup
# cf. backup/NETFS/default/400_create_include_exclude_files.sh
Log "Backup include list (backup-include.txt contents):"
while read -r backup_include_item ; do
    test "$backup_include_item" && Log "  $backup_include_item"
done < $TMP_DIR/backup-include.txt
Log "Backup exclude list (backup-exclude.txt contents):"
while read -r backup_exclude_item ; do
    test "$backup_exclude_item" && Log "  $backup_exclude_item"
done < $TMP_DIR/backup-exclude.txt

# Check if the backup needs to be splitted or not (on multiple ISOs)
if [[ -n "$ISO_MAX_SIZE" ]]; then
    # Computation of the real backup maximum size by excluding bootable files size on the first ISO (EFI, kernel, ramdisk)
    # Don't use that on max size less than 200MB which would result in too many backups
    if [[ $ISO_MAX_SIZE -gt 200 ]]; then
        INITRD_SIZE=$(stat -c '%s' $TMP_DIR/$REAR_INITRD_FILENAME)
        KERNEL_SIZE=$(stat -c '%s' $KERNEL_FILE)
        # We add 15MB which is the average size of all isolinux binaries
        BASE_ISO_SIZE=$(((${INITRD_SIZE}+${KERNEL_SIZE})/1024/1024+15))
        # If we are EFI, add 30MB (+ previous 15MB), UEFI files can't exceed this size
        is_true $USING_UEFI_BOOTLOADER && BASE_ISO_SIZE=$((${BASE_ISO_SIZE}+30))
        ISO_MAX_SIZE=$((${ISO_MAX_SIZE}-${BASE_ISO_SIZE}))
    fi
    SPLIT_COMMAND="split -d -b ${ISO_MAX_SIZE}m - ${backuparchive}."
else
    SPLIT_COMMAND="dd of=$backuparchive"
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
                $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE \| $BACKUP_PROG_CRYPT_OPTIONS BACKUP_PROG_CRYPT_KEY \| $SPLIT_COMMAND
        else
            Log $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose \
                --no-wildcards-match-slash --one-file-system \
                --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}" \
                $BACKUP_PROG_CREATE_NEWER_OPTIONS \
                ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS} "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" \
                -X $TMP_DIR/backup-exclude.txt -C / -c -f - \
                $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE \| $SPLIT_COMMAND
        fi

        # Variable used to record the short name of piped commands in case of
        # error, e.g. ( "tar" "cat" "dd" ) in case of unencrypted and unsplit backup.
        backup_prog_shortnames=(
            "$(basename $(echo "$BACKUP_PROG" | awk '{ print $1 }'))"
            "$(basename $(echo "$BACKUP_PROG_CRYPT_OPTIONS" | awk '{ print $1 }'))"
            "$(basename $(echo "$SPLIT_COMMAND" | awk '{ print $1 }'))"
        )
        for index in ${!backup_prog_shortnames[@]} ; do
            [ -n "${backup_prog_shortnames[$index]}" ] || BugError "No computed shortname for pipe component $index"
        done

        if is_true "$BACKUP_PROG_CRYPT_ENABLED" ; then
            $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose    \
                --no-wildcards-match-slash --one-file-system                        \
                --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}"                    \
                $BACKUP_PROG_CREATE_NEWER_OPTIONS                                   \
                ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS}                       \
                "${BACKUP_PROG_COMPRESS_OPTIONS[@]}"                                \
                -X $TMP_DIR/backup-exclude.txt -C / -c -f -                         \
                $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE |               \
            { $BACKUP_PROG_CRYPT_OPTIONS "$BACKUP_PROG_CRYPT_KEY" ; } 2>/dev/null | \
            $SPLIT_COMMAND
            pipes_rc=( ${PIPESTATUS[@]} )
        else
            $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose    \
                --no-wildcards-match-slash --one-file-system                        \
                --ignore-failed-read "${BACKUP_PROG_OPTIONS[@]}"                    \
                $BACKUP_PROG_CREATE_NEWER_OPTIONS                                   \
                ${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS}                       \
                "${BACKUP_PROG_COMPRESS_OPTIONS[@]}"                                \
                -X $TMP_DIR/backup-exclude.txt -C / -c -f -                         \
                $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE |               \
            $SPLIT_COMMAND
            pipes_rc=( ${PIPESTATUS[@]} )
        fi

        # Exit code logic:
        # - never return rc=1 (this is reserved for "tar" warning about modified files)
        # - process exit code in pipe's reverse order
        #   - if last command failed (e.g. "dd"), return an error
        #   - otherwise if previous command failed (e.g. "encrypt"), return an error
        #   ...
        #   - otherwise return "tar" exit code
        #
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
                exit $rc
            fi
            # This pipe command succeeded, check the previous one
            let index--
        done
        # This was a success
        exit 0
    ;;
    (rsync)
        # make sure that the target is a directory
        mkdir -p $v "$backuparchive" >&2
        Log $BACKUP_PROG --verbose "${BACKUP_RSYNC_OPTIONS[@]}" --one-file-system --delete \
            --exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded \
            $(cat $TMP_DIR/backup-include.txt) "$backuparchive"
        $BACKUP_PROG --verbose "${BACKUP_RSYNC_OPTIONS[@]}" --one-file-system --delete \
            --exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded \
            $(cat $TMP_DIR/backup-include.txt) "$backuparchive" >&2
    ;;
    (*)
        Log "Using unsupported backup program '$BACKUP_PROG'"
        Log $BACKUP_PROG "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" \
            $BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $TMP_DIR/backup-exclude.txt \
            "${BACKUP_PROG_OPTIONS[@]}" $backuparchive \
            $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE > $backuparchive
        $BACKUP_PROG "${BACKUP_PROG_COMPRESS_OPTIONS[@]}" \
            $BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $TMP_DIR/backup-exclude.txt \
            "${BACKUP_PROG_OPTIONS[@]}" $backuparchive \
            $(cat $TMP_DIR/backup-include.txt) $RUNTIME_LOGFILE > $backuparchive
    ;;
esac 2> "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log"
# important trick: the backup prog is the last in each case entry and the case .. esac is the last command
# in the (..) subshell. As a result the return code of the subshell is the return code of the backup prog!
) &
BackupPID=$!
starttime=$SECONDS

sleep 1 # Give the backup software a good chance to start working

# return disk usage in bytes
function get_disk_used() {
    let "$(stat -f -c 'used=(%b-%f)*%S' $1)"
    echo $used
}

# While the backup runs in a sub-process, display some progress information to the user.
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

sleep 1

# everyone should see this warning, even if not verbose
case "$(basename $BACKUP_PROG)" in
    (tar)
        if (( $backup_prog_rc != 0 )); then
            prog="$(cat $FAILING_BACKUP_PROG_FILE)"
            if (( $backup_prog_rc == 1 )); then
                LogUserOutput "WARNING: $prog ended with return code 1 and below output:
  ---snip---
$(grep '^tar: ' "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" | sed -e 's/^/  /' | tail -n3)
  ----------
This means that files have been modified during the archiving
process. As a result the backup may not be completely consistent
or may not be a perfect copy of the system. Relax-and-Recover
will continue, however it is highly advisable to verify the
backup in order to be sure to safely recover this system.
"
            else
                rc=$(cat $FAILING_BACKUP_PROG_RC_FILE)
                Error "$prog failed with return code $rc and below output:
  ---snip---
$(grep "^$prog: " "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" | sed -e 's/^/  /' | tail -n3)
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
