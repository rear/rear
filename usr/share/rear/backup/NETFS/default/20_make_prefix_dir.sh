
# if set, create $NETFS_PREFIX under the mounted network filesystem share. This defaults
# to uname -n

mkdir -p $v -m0750 "${BUILD_DIR}/netfs/${NETFS_PREFIX}" >&2
StopIfError "Could not mkdir '${BUILD_DIR}/netfs/${NETFS_PREFIX}'"
