
# if set, create $NETFS_PREFIX under the mounted network filesystem share. This defaults
# to uname -n

if ! test -d "${BUILD_DIR}/netfs/${NETFS_PREFIX}" ; then
	mkdir -m 750 -p "${BUILD_DIR}/netfs/${NETFS_PREFIX}" || \
		Error "Could not mkdir '${BUILD_DIR}/netfs/${NETFS_PREFIX}'"
fi
