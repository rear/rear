# create a lockfile in $NETFS_PREFIX to avoid that mkrescue overwrites ISO/LOGFILE
# made by a previous mkbackup run when the variable NETFS_KEEP_OLD_BACKUP_COPY has been set

if test -d "${BUILD_DIR}/netfs/${NETFS_PREFIX}" ; then
	> "${BUILD_DIR}/netfs/${NETFS_PREFIX}/.lockfile" || \
		Error "Could not create '${BUILD_DIR}/netfs/${NETFS_PREFIX}/.lockfile'"
fi
