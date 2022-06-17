# Create RSYNC_PREFIX under the local TMP_DIR and also on remote rsync server
# RSYNC_PREFIX=$HOSTNAME as set in default.conf

local proto host

proto="$(rsync_proto "$OUTPUT_URL")"
host="$(rsync_host "$OUTPUT_URL")"

# create temporary local work-spaces to collect files
mkdir -p $v -m0750 "${TMP_DIR}/rsync/${RSYNC_PREFIX}" >&2 || Error "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}'"

case $proto in

	(ssh)
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" "$(rsync_remote "$OUTPUT_URL")" >/dev/null 2>&1 \
                    || Error "Could not create '$(rsync_path_full "$OUTPUT_URL")' on remote ${host}"
		;;

	(rsync)
		# This must run before the backup stage. Otherwise --relative gets added to BACKUP_RSYNC_OPTIONS
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" "${BACKUP_RSYNC_OPTIONS[@]}" "$(rsync_remote "$OUTPUT_URL")/" >/dev/null \
                    || Error "Could not create '$(rsync_path_full "$OUTPUT_URL")' on remote ${host}"
		;;

esac
