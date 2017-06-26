#
# some backup SW doesn't restore mountpoints properly
#
#
# create missing directories
pushd $TARGET_FS_ROOT >/dev/null
mkdir -p mnt proc sys tmp dev/pts dev/shm
chmod 1777 tmp
popd >/dev/null
