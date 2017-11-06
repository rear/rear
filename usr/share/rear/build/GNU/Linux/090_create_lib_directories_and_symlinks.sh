# mirror library dir structure
Log "Mirroring lib/ structure."

for libdir in /lib* /usr/lib*; do
    if [[ -L $libdir ]] ; then
        libdir_basedir=$(dirname $libdir)
        target=$(readlink -f $libdir)

        if [[ ! -e $ROOTFS_DIR$target ]] ; then
            mkdir $v -p $ROOTFS_DIR$target >&2
        fi

        pushd ${ROOTFS_DIR}${libdir_basedir} >/dev/null
        cp -d $libdir ./
        popd >/dev/null
    else
        mkdir $v -p $ROOTFS_DIR$libdir >&2
    fi
done
