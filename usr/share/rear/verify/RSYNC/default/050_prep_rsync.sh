# 050_prep_rsync.sh : prepare rsync usage
# define rsync as BACKUP_PROG and not tar (which is the default)
# $BACKUP_PROG could contain full path to executable on purpose
case $BACKUP_PROG in
	(tar)	BACKUP_PROG=rsync ;;		# if nothing was set nor defined
	(rsync)	: ;;				# was defined correctly
	(*)	[[ ! -x $BACKUP_PROG ]] && BACKUP_PROG=rsync
esac


PROGS+=( $BACKUP_PROG gzip bzip2 )

rsync_err_msg=(
"Success"
"Syntax or usage error"
"Protocol incompatibility"
"Errors selecting input/output files, dirs"
"Requested action not supported"
"Error starting client-server protocol"
"Daemon unable to append to log-file"
"Error 7"
"Error 8"
"Error 9"
"Error in socket I/O"
"Error in file I/O"
"Error in rsync protocol data stream"
"Errors with program diagnostics"
"Error in IPC code"
"Error 15"
"Error 16"
"Error 17"
"Error 18"
"Error 19"
"Received SIGUSR1 or SIGINT"
"Some error returned by waitpid()"
"Error allocating core memory buffers"
"Partial transfer due to error"
"Partial transfer due to vanished source files"
"The --max-delete limit stopped deletions"
"Error 26"
"Error 27"
"Error 28"
"Error 29"
"Timeout in data send/receive"
"Error 31"
"Error 32"
"Error 33"
"Error 34"
"Timeout waiting for daemon connection"
)
