# many systems now use udev and thus have an empty /dev
# this prevents our chrooted grub install later on, so we copy
# the /dev from our rescue system to the freshly installed system
cp -fa /dev $TARGET_FS_ROOT/
