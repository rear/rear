# umount ISO mountpoint

if [[ "$ISO_UMOUNTCMD" ]] ; then
    ISO_URL="var://NETFS_UMOUNTCMD"
fi

if [[ -z "$ISO_URL" ]] ; then
    return
fi

umount_url $ISO_URL $BUILD_DIR/outputfs

rmdir $v $BUILD_DIR/outputfs >&2
if [[ $? -eq 0 ]] ; then
    # the argument to RemoveExitTask has to be identical to the one given to AddExitTask
    RemoveExitTask "rmdir $v $BUILD_DIR/outputfs >&2"
fi