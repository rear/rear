# Add path to CommVault Base Dir to rescue system
cat >>$ROOTFS_DIR/etc/profile.d/galaxy11.sh <<EOF
PATH=\$PATH:$GALAXY11_HOME_DIRECTORY
EOF
