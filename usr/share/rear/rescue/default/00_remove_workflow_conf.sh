#
# set extra config options for recovery phase
#
# this is useful to bring over some settings from the build system to the 
# rescue system that would be hard to find out there

test -d $ROOTFS_DIR$CONFIG_DIR || mkdir -p $ROOTFS_DIR$CONFIG_DIR

# the following line is probably deep legacy and should be removed when I don't remember what it is for
rm -f $CONFIG_DIR/{dump,recover}.conf # so that the file in the ROOTFS_DIR won't be overwritten

