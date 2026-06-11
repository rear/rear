Log "Fixup debian jessie systemd files"

# on debian jessie systemd files are located in /lib/systemd not
# /usr/lib/systemd, as such symlink then within the $ROOTFS_DIR
# otherwise certain services won't come up.

if [ -e "$ROOTFS_DIR/lib/systemd/" ]; then
    cd  $ROOTFS_DIR/lib/systemd/
    my_systemd_files=( $( ls -1 systemd-* ))
    if [ -e "$ROOTFS_DIR/usr/lib/systemd/" ]; then
        cd  $ROOTFS_DIR/usr/lib/systemd/
        for m in "${my_systemd_files[@]}" ; do
	        ln -sf  ../../../lib/systemd/$m $m
        done
    else
        Error "Missing usr/lib/systemd/system - too confused to continue"
    fi
fi
