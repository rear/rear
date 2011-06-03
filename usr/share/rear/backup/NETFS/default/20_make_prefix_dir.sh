
# if set, create $NETFS_PREFIX under the mounted network filesystem share. This defaults
# to uname -n

mkdir -p -m0750 "${BUILD_DIR}/netfs/${NETFS_PREFIX}"
StopIfError "Could not mkdir '${BUILD_DIR}/netfs/${NETFS_PREFIX}'"
