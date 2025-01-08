# Recreate some directories/symlinks in the rescue system if present.
# Eventually more stuff from $SHARE_DIR/skel could be moved here.
# The main use is for symlinks, as their presence in the source tree
# (under $SHARE_DIR/skel) brings some problems.
# See https://docs.fedoraproject.org/en-US/packaging-guidelines/Directory_Replacement/

local d
local skeleton_paths=( /var/run )

for d in "${skeleton_paths[@]}" ; do
    if ! [ -e "$d" ] ; then
        Debug "Skeleton path '$d' not present, not creating it under $ROOTFS_DIR"
        continue
    fi
    # test whether it is a symlink first - other tests than -L
    # dereference symlinks, so we would not be able to tell directories
    # from symlinks otherwise
    if [ -L "$d" ] ; then
        # We could of course remove it and replace, but this should not happen,
        # so erroring out is safer
        [ -e "$ROOTFS_DIR/$d" ] && BugError "'$ROOTFS_DIR/$d' already exists - remove '$d' from $SHARE_DIR/skel if it is present there"
        cp -a "$d" "$ROOTFS_DIR/$d" || Error "Failed to copy '$d' symlink to $ROOTFS_DIR"
    elif [ -d "$d" ] ; then
        mkdir -p "$ROOTFS_DIR/$d" || Error "Failed to create directory '$ROOTFS_DIR/$d'"
    else
        # We could implement support for other file types here,
        # but it is probably better to use the COPY_AS_IS variable for them.
        BugError "Not creating '$d' under $ROOTFS_DIR - neither a symlink nor a directory"
    fi
done
