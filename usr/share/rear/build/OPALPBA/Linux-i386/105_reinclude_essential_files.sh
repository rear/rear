# Re-include essential files which have been previously excluded

mkdir $v -p "$ROOTFS_DIR/$REAR_DIR_PREFIX/usr/share/rear/lib"
cp $v "$REAR_DIR_PREFIX/usr/share/rear/lib"/*-functions.sh "$ROOTFS_DIR/$REAR_DIR_PREFIX/usr/share/rear/lib"
StopIfError "Could not re-include essential files"
