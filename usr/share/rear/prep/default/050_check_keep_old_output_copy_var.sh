# align the variables NETFS_KEEP_OLD_BACKUP_COPY and KEEP_OLD_OUTPUT_COPY
[[ ! -z "$KEEP_OLD_OUTPUT_COPY" ]] && return  # if KEEP_OLD_OUTPUT_COPY=y just return
[[ -z "$KEEP_OLD_OUTPUT_COPY" ]] && [[ ! -z "$NETFS_KEEP_OLD_BACKUP_COPY" ]] && \
    [[ "$WORKFLOW" = "mkbackup" ]] &&  KEEP_OLD_OUTPUT_COPY=y
