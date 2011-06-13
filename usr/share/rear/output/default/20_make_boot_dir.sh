# create dir to keep all the boot files (besides kernel and initrd)
mkdir -p $v "$BUILD_DIR/boot" >&2
StopIfError "Could not mkdir $BUILD_DIR/boot"
