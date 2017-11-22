# Re-include essential files which have been previously excluded

mkdir $v -p "$ROOTFS_DIR/$REAR_DIR_PREFIX/usr/share/rear/lib"
cp $v -r "$REAR_DIR_PREFIX/usr/share/rear/lib/." "$ROOTFS_DIR/$REAR_DIR_PREFIX/usr/share/rear/lib"
StopIfError "Could not re-include essential files"
