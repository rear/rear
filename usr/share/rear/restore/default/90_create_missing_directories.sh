#
# some backup SW doesn't restore mountpoints properly
#
#
# create missing directories
pushd /mnt/local >&8
mkdir -p mnt proc sys tmp dev/pts dev/shm
chmod 1777 tmp
popd >&8
