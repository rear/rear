# build/default/985_fix_broken_links.sh
# Check for broken symbolic links in our ROOTFS_DIR area - issue #1638

pushd $ROOTFS_DIR >/dev/null
    find . -xtype l | grep -v "/dev/" | while read SYMLINK
    do
        mising_file=$( ls -l $SYMLINK | awk '{print $11}' | sed -e 's/\.//g' )
        test -d $(dirname ./$mising_file) || mkdir -m 755 -p $(dirname ./$mising_file)
        cp -v $mising_file ./$mising_file >&2
    done
popd >/dev/null
