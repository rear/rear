#
# some backup SW doesn't restore mountpoints properly
#
#
# create missing directories
pushd /mnt/local >/dev/null
for dir in mnt proc sys tmp dev/pts dev/shm ; do
        test -d "$dir" || mkdir -p "$dir"
done
chmod 1777 tmp
popd >/dev/null
