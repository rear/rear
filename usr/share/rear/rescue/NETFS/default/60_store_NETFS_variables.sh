# store all NETFS* variables
# I don't know why it does not work with the full declare -- var=value syntax
# found out by experiment that I need to remove the declare -- stuff.
declare -p ${!NETFS*} | sed -e 's/declare .. //' >>$ROOTFS_DIR/etc/rear/rescue.conf
