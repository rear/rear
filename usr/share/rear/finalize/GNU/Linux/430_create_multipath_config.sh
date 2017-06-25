# multipath configuration used in recovery must be saved to TARGET_FS_ROOT if they
# don't exists. This should only happen if you migrate from a non-multipath system to
# a multipath one.

# This phase must be done before rebuilding initramfs.

if multipath -d >/dev/null ; then

    if [ ! -f $TARGET_FS_ROOT/etc/multipath.conf ] ; then
        LogPrint "/etc/multipath.conf not available in target, creating it..."
        if [ -f /etc/multipath.conf ] ; then
            cp /etc/multipath.conf $TARGET_FS_ROOT/etc/multipath.conf
        fi
    fi

    [ ! -d  $TARGET_FS_ROOT/etc/multipath ] && mkdir -p $TARGET_FS_ROOT/etc/multipath

    # Always copy multipath bindings file to the $TARGET_FS_ROOT. In case of migration to different multipath diks (migration)
    # /etc/multipath/bindings has been updated in the recovery image and result must ALWAYS be copied to the TARGET_FS_ROOT
    # before mkinitrd operation.
    if [ -f /etc/multipath/bindings ] ; then
        cp /etc/multipath/bindings $TARGET_FS_ROOT/etc/multipath/bindings && LogPrint "/etc/multipath/bindings copied to $TARGET_FS_ROOT"
        LogIfError "Failed to copy /etc/multipath/bindings to $TARGET_FS_ROOT"
    fi

    # Cleaning /etc/multipath/wwids file and update it with new wwids.
    if mount -t proc none $TARGET_FS_ROOT/proc ; then
        chroot $TARGET_FS_ROOT /bin/bash -c 'PATH=/sbin:/usr/sbin:/usr/bin:/bin multipath -W' || LogPrint "Failed to reset wwids on target"
    else
        LogPrint "Failed to mount proc FS on target. multipath wwids not updated."
    fi
fi
