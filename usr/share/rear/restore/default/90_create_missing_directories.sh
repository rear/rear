#
# some backup SW doesn't restore mountpoints properly
#
#
# create missing directories
pushd /mnt/local >&8
if [[ -f "$VAR_DIR/recovery/mountpoint_permissions" ]] ; then
    LogPrint "Restore the Mountpoints (with permissions) from $VAR_DIR/recovery/mountpoint_permissions"
    while read _dir mode userid groupid
    do
        ! [[ -d "$_dir" ]] && mkdir -p $_dir
        chmod $mode $_dir
        chown $userid:$groupid $_dir
    done < <(cat "$VAR_DIR/recovery/mountpoint_permissions")
elif [[ -z "$MOUNTPOINTS_TO_RESTORE" ]] ; then
    # keep this for backward compatibility 
    mkdir -p mnt proc run sys tmp dev/pts dev/shm
else
    # keep this for backward compatibility 
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
