#
# CommVault uses a special group which we need to copy to the rescue system
#

# append group info to /etc/group if it is not root (0)
galaxy_group=$(stat -L -c "%g" "$GALAXY11_HOME_DIRECTORY/Galaxy")
if test "$galaxy_group" && (( galaxy_group > 0 )) ; then
    getent group $galaxy_group >>$ROOTFS_DIR/etc/group
fi
