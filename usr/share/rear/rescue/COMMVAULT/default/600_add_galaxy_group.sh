#
# Galaxy uses a special group which we need to copy to the rescue system
#

# append group info to /etc/group if it is not root (0)
galaxy_group=$(stat -c "%g" /opt/commvault/Base64/Galaxy)
test $galaxy_group -gt 0 && getent group $galaxy_group >>$ROOTFS_DIR/etc/group
