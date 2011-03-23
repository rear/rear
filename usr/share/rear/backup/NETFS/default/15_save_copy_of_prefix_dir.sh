# if NETFS_KEEP_OLD_BACKUP_COPY is not empty then move old NETFS_PREFIX directory to NETFS_PREFIX.old
if ! test -z "${NETFS_KEEP_OLD_BACKUP_COPY}"; then
	if ! test -f "${BUILD_DIR}/netfs/${NETFS_PREFIX}/.lockfile" ; then
		# lockfile made through workflow backup already (so output keep hands off)
		if test -d "${BUILD_DIR}/netfs/${NETFS_PREFIX}" ; then
			rm -rf "${BUILD_DIR}/netfs/${NETFS_PREFIX}.old" || \
				Error "Could not remove '${BUILD_DIR}/netfs/${NETFS_PREFIX}.old'"
			mv -f "${BUILD_DIR}/netfs/${NETFS_PREFIX}" "${BUILD_DIR}/netfs/${NETFS_PREFIX}.old" || \
				Error "Could not move '${BUILD_DIR}/netfs/${NETFS_PREFIX}'"
		fi
	else
		Log "Lockfile '${BUILD_DIR}/netfs/${NETFS_PREFIX}/.lockfile' found. Not keeping old backup data."
	fi
fi
# the ${BUILD_DIR}/netfs/${NETFS_PREFIX} will be created by output/NETFS/default/20_make_prefix_dir.sh
