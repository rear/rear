#
# some backup SW doesn't restore mountpoints properly
#
#
# create missing directories
pushd /mnt/local >&8
if [ -z "$MOUNTPOINTS_TO_RESTORE" ]; then 
    mkdir -p mnt proc run sys tmp dev/pts dev/shm
else
    LogPrint "Restore the Mountpoints $MOUNTPOINTS_TO_RESTORE".
    mkdir -p $MOUNTPOINTS_TO_RESTORE
    # ensure some important mountpoints will be restored:
    for _dir in mnt proc sys tmp dev/pts dev/shm
    do
      ! [ -d "$_dir" ] && mkdir -p $_dir
    done
fi
chmod 1777 tmp
popd >&8
