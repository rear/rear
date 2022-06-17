# Create RSYNC_PREFIX under the local TMP_DIR and also on remote rsync server
# RSYNC_PREFIX=$HOSTNAME as set in default.conf

local proto host

proto="$(rsync_proto "$OUTPUT_URL")"
host="$(rsync_host "$OUTPUT_URL")"

# create temporary local work-spaces to collect files (we already make the remote backup dir with the correct mode!!)
mkdir -p $v -m0750 "${TMP_DIR}/rsync/${RSYNC_PREFIX}" >&2 || Error "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}'"
mkdir -p $v -m0755 "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup" >&2 || Error "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup'"

case $proto in

	(ssh)
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" "$(rsync_remote "$OUTPUT_URL")" >/dev/null 2>&1 \
                    || Error "Could not create '$(rsync_path_full "$OUTPUT_URL")' on remote ${host}"
		;;

	(rsync)
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" "${BACKUP_RSYNC_OPTIONS[@]}" "$(rsync_remote "$OUTPUT_URL")/" >/dev/null \
                    || Error "Could not create '$(rsync_path_full "$OUTPUT_URL")' on remote ${host}"
		;;

esac
