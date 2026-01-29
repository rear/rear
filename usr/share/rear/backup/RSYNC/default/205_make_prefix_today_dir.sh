# 205_make_prefix_today_dir.sh is meant to be used when BACKUP_RSYNC_RETENTION_DAYS non-empty (integer)
# Create RSYNC_PREFIX/backup/$RSYMC_TODAY on remote rsync server
# RSYNC_PREFIX=$HOSTNAME as set in default.conf

[[ -z "$BACKUP_RSYNC_RETENTION_DAYS" ]] && return   # empty means no retention is requested

# As BACKUP_RSYNC_RETENTION_DAYS only supports ssh protocol with rsync we do not need to check the protocol again
# as in prep/RSYNC/GNU/Linux/210_rsync_retention_days.sh we perform the explicit check already.

mkdir -p $v -m0755 "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup/${RSYNC_TODAY}" >&2 || Error "Could not mkdir '${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup/${RSYNC_TODAY}'"

$BACKUP_PROG -a $v -r "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup/${RSYNC_TODAY}" "$(rsync_remote "${BACKUP_URL}/${RSYNC_PREFIX}/backup")" >/dev/null 2>&1 \
    || Error "Could not create '$(rsync_path_full "$BACKUP_URL")' on remote ${host}"

# We don't need it anymore, from now we operate on the remote copy
rmdir $v "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup/$RSYNC_TODAY"
rmdir $v "${TMP_DIR}/rsync/${RSYNC_PREFIX}/backup"
rmdir $v "${TMP_DIR}/rsync/${RSYNC_PREFIX}"
