#
# set extra config options for recovery phase
#
# this is useful to bring over some settings from the build system to the
# rescue system that would be hard to find out there

mkdir -p $v $ROOTFS_DIR/etc/rear >&2

# we can write stuff to $CONFIG_DIR/rescue.conf if we want to preserve some dynamic variables
# so that they stay static in the rescue system. static means they stay the same as when the
# rescue system was created.
rm -f $v $ROOTFS_DIR/etc/rear/rescue.conf >&2

