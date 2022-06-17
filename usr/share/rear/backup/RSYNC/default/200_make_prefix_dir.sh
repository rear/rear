# Create RSYNC_PREFIX/backup on remote rsync server
# RSYNC_PREFIX=$HOSTNAME as set in default.conf

local proto host

proto="$(rsync_proto "$BACKUP_URL")"
host="$(rsync_host "$BACKUP_URL")"

mkdir -p $v -m0750 "${TMP_DIR}/rsync/${RSYNC_PREFIX}" >&2 || Error "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}'"
mkdir -p $v -m0755 "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup" >&2 || Error "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup'"

case $proto in

	(ssh)
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" "$(rsync_remote "$BACKUP_URL")" >/dev/null 2>&1 \
                    || Error "Could not create '$(rsync_path_full "$BACKUP_URL")' on remote ${host}"
		;;

	(rsync)
		$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}" "${BACKUP_RSYNC_OPTIONS[@]}" "$(rsync_remote "$BACKUP_URL")/" >/dev/null \
                    || Error "Could not create '$(rsync_path_full "$BACKUP_URL")' on remote ${host}"
		;;

esac

# We don't need it anymore, from now we operate on the remote copy
rmdir $v "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup"
rmdir $v "${TMP_DIR}/rsync/${RSYNC_PREFIX}"
