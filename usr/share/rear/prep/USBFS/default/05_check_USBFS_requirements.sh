# set archive names
backuparchive="${BUILD_DIR}/netfs/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}"
displayarchive="$backuparchive"

# include required programs
# please note that this is just for safety reasons. Most of these programs are also listed in conf/GNU/Linux.conf !

PROGS=( "${PROGS[@]}"
ping
$( 
test "$USBFS_MOUNTCMD" && echo "${USBFS_MOUNTCMD%% *}"
test "$USBFS_UMOUNTCMD" && echo "${USBFS_UMOUNTCMD%% *}"
)
$BACKUP_PROG
gzip
bzip2
)
