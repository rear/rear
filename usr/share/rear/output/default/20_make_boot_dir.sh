# create dir to keep all the boot files (besides kernel and initrd)
mkdir -p $v "$TMP_DIR/boot" >&2
StopIfError "Could not mkdir $TMP_DIR/boot"
