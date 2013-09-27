# 50_make_backup.sh
#

function set_tar_features {
    # Default tar options
    TAR_OPTIONS=

    # Test for features in tar
    # true if at supports the --warning option (v1.23+)
    FEATURE_TAR_WARNINGS=

    local tar_version=$(get_version tar --version)

    if version_newer "$tar_version" 1.23; then
        FEATURE_TAR_WARNINGS="y"
        TAR_OPTIONS="$TAR_OPTIONS --warning=no-xdev"
    fi

    FEATURE_TAR_IS_SET=1
}


Log "Include list:"
while read -r ; do
	Log "  $REPLY"
done < $TMP_DIR/backup-include.txt
Log "Exclude list:"
while read -r ; do
	Log " $REPLY"
done < $TMP_DIR/backup-exclude.txt

local scheme=$(url_scheme $BACKUP_URL)
local path=$(url_path $BACKUP_URL)
local opath=$(backup_path $scheme $path)

if [[ "$opath" ]]; then
    mkdir -p $v "${opath}" >&2
fi

# Disable BACKUP_PROG_CRYPT_OPTIONS by replacing the default value to cat in 
# case encryption is disabled
if (( $BACKUP_PROG_CRYPT_ENABLED == 1 )); then
  LogPrint "Encrypting archive with key: $BACKUP_PROG_CRYPT_KEY"
else
  LogPrint "Encrypting disabled"
  BACKUP_PROG_CRYPT_OPTIONS="cat"
  BACKUP_PROG_CRYPT_KEY=""
fi 

# Check if the backup needs to be splitted or not
if [[ -n "$ISO_MAX_SIZE" ]]; then
    # Computation of the real backup maximum size by excluding bootable files size on the first ISO (EFI, kernel, ramdisk)
    # Don't use that on max size less than 200MB which would result in too many backups
    if [[ $ISO_MAX_SIZE -gt 200 ]]; then
        INITRD_SIZE=$(stat -c '%s' $TMP_DIR/initrd.cgz)
        KERNEL_SIZE=$(stat -c '%s' $KERNEL_FILE)
        # We add 15MB which is the average size of all isolinux binaries
        BASE_ISO_SIZE=$(((${INITRD_SIZE}+${KERNEL_SIZE})/1024/1024+15))
        # If we are EFI, add 30MB (+ previous 15MB), UEFI files can't exceed this size
        [[ $USING_UEFI_BOOTLOADER ]] && BASE_ISO_SIZE=$((${BASE_ISO_SIZE}+30))
        ISO_MAX_SIZE=$((${ISO_MAX_SIZE}-${BASE_ISO_SIZE}))
    fi
    SPLIT_COMMAND="split -d -b ${ISO_MAX_SIZE}m - ${backuparchive}."
else
    SPLIT_COMMAND="dd of=$backuparchive"
fi

LogPrint "Creating $BACKUP_PROG archive '$backuparchive'"
ProgressStart "Preparing archive operation"
(
case "$(basename ${BACKUP_PROG})" in
	# tar compatible programs here
	(tar)
		set_tar_features
		Log $BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose \
			--no-wildcards-match-slash --one-file-system \
			--ignore-failed-read $BACKUP_PROG_OPTIONS \
			$BACKUP_PROG_X_OPTIONS \
			${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS} $BACKUP_PROG_COMPRESS_OPTIONS \
			-X $TMP_DIR/backup-exclude.txt -C / -c -f - \
			$(cat $TMP_DIR/backup-include.txt) $LOGFILE \| $BACKUP_PROG_CRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY \| $SPLIT_COMMAND
		$BACKUP_PROG $TAR_OPTIONS --sparse --block-number --totals --verbose \
			--no-wildcards-match-slash --one-file-system \
			--ignore-failed-read $BACKUP_PROG_OPTIONS \
			$BACKUP_PROG_X_OPTIONS \
			${BACKUP_PROG_BLOCKS:+-b $BACKUP_PROG_BLOCKS} $BACKUP_PROG_COMPRESS_OPTIONS \
			-X $TMP_DIR/backup-exclude.txt -C / -c -f - \
			$(cat $TMP_DIR/backup-include.txt) $LOGFILE | $BACKUP_PROG_CRYPT_OPTIONS $BACKUP_PROG_CRYPT_KEY | $SPLIT_COMMAND
	;;
	(rsync)
		# make sure that the target is a directory
		mkdir -p $v "$backuparchive" >&2
		Log $BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" --one-file-system --delete \
			--exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded \
			$(cat $TMP_DIR/backup-include.txt) "$backuparchive"
		$BACKUP_PROG "${BACKUP_RSYNC_OPTIONS[@]}" --one-file-system --delete \
			--exclude-from=$TMP_DIR/backup-exclude.txt --delete-excluded \
			$(cat $TMP_DIR/backup-include.txt) "$backuparchive"
	;;
	(*)
		Log "Using unsupported backup program '$BACKUP_PROG'"
		Log $BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $TMP_DIR/backup-exclude.txt \
			$BACKUP_PROG_OPTIONS $backuparchive \
			$(cat $TMP_DIR/backup-include.txt) $LOGFILE > $backuparchive
		$BACKUP_PROG $BACKUP_PROG_COMPRESS_OPTIONS \
			$BACKUP_PROG_OPTIONS_CREATE_ARCHIVE $TMP_DIR/backup-exclude.txt \
			$BACKUP_PROG_OPTIONS $backuparchive \
			$(cat $TMP_DIR/backup-include.txt) $LOGFILE > $backuparchive
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
# while the backup runs in a sub-process, display some progress information to the user
case "$(basename ${BACKUP_PROG})" in
	(tar)
		while sleep 1 ; kill -0 $BackupPID 2>&8; do
			#blocks="$(stat -c %b ${backuparchive})"
			#size="$((blocks*512))"
			size="$(stat -c %s ${backuparchive}* | awk '{s+=$1} END {print s}')"
			#echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
			ProgressInfo "Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		;;
	(rsync)
		# since we do not want to do a $(du -s) run every second we count disk usage instead
		# this obviously leads to wrong results in case something else is writing to the same
		# disk at the same time as is very likely with a networked file system. For local disks
		# this should be good enough and in any case this is only some eye candy.
		# TODO: Find a fast way to count the actual transfer data, preferrable getting the info from rsync.
		let old_disk_used="$(get_disk_used "$backuparchive")"
		while sleep 1 ; kill -0 $BackupPID 2>&8; do
			let disk_used="$(get_disk_used "$backuparchive")" size=disk_used-old_disk_used
			#echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
			ProgressInfo "Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
		done
		;;
	(*)
		while sleep 1 ; kill -0 $BackupPID 2>&8; do
			size="$(stat -c "%s" "$backuparchive")" || {
				kill -9 $BackupPID
				ProgressError
				Error "$(basename $BACKUP_PROG) failed to create the archive file"
			}
			#echo -en "\e[2K\rArchived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
			ProgressInfo "Archived $((size/1024/1024)) MiB [avg $((size/1024/(SECONDS-starttime))) KiB/sec]"
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
        if (( $backup_prog_rc == 1 )); then
            LogPrint "WARNING: $(basename $BACKUP_PROG) ended with return code $backup_prog_rc and below output:
  ---snip---
$(grep '^tar: ' $LOGFILE | sed -e 's/^/  /' | tail -n3)
  ----------
This means that files have been modified during the archiving
process. As a result the backup may not be completely consistent
or may not be a perfect copy of the system. Relax-and-Recover
will continue, however it is highly advisable to verify the
backup in order to be sure to safely recover this system.
"
        elif (( $backup_prog_rc > 1 )); then
            Error "$(basename $BACKUP_PROG) failed with return code $backup_prog_rc and below output:
  ---snip---
$(grep '^tar: ' $LOGFILE | sed -e 's/^/  /' | tail -n3)
  ----------
This means that the archiving process ended prematurely, or did
not even start. As a result it is unlikely you can recover this
system properly. Relax-and-Recover is therefore aborting execution.
"
        fi;;
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

tar_message="$(tac $LOGFILE | grep -m1 '^Total bytes written: ')"
if [ $backup_prog_rc -eq 0 -a "$tar_message" ] ; then
	LogPrint "$tar_message in $transfertime seconds."
elif [ "$size" ]; then
	LogPrint "Archived $((size/1024/1024)) MiB in $((transfertime)) seconds [avg $((size/1024/transfertime)) KiB/sec]"
fi

### Copy progress log to backup media
cp $v "${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log" "${opath}/${BACKUP_PROG_ARCHIVE}.log" >&2
