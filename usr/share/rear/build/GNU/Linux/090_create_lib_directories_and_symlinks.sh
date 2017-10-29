# mirror library dir structure
Log "Mirroring lib/ structure."
for libdir in /lib* /usr/lib* ; do
    if [[ -L $libdir ]] ; then
        target=$(readlink $libdir)

        if [[ ! -e $ROOTFS_DIR$target ]] ; then
            mkdir $v -p $ROOTFS_DIR$target >&2
        fi
        ### move into ROOTFS_DIR to create 'absolute' symlinks
        pushd $ROOTFS_DIR >/dev/null
        ln $v -sf ${target#/} ${libdir#/} >&2
        popd >/dev/null
    else
        mkdir $v -p $ROOTFS_DIR$libdir >&2
    fi
done
