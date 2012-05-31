# mirror library dir structure
Log "Mirroring lib/ structure."
for libdir in /lib* /usr/lib* ; do
    if [[ -L $libdir ]] ; then
        target=$(readlink -f $libdir)

        if [[ ! -e $ROOTFS_DIR$target ]] ; then
            mkdir $v -p $ROOTFS_DIR$target >&2
        fi
        ln $v -sf $target $ROOTFS_DIR$libdir >&2
    else
        mkdir $v -p $ROOTFS_DIR$libdir >&2
    fi
done
