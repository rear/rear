set_syslinux_features

cp -L $v "$ISO_ISOLINUX_BIN" $TMP_DIR/boot/isolinux.bin >&2

make_syslinux_config $TMP_DIR/boot isolinux >$TMP_DIR/boot/isolinux.cfg

Log "Created isolinux configuration"

# add all files that we need for booting to ISO_FILES
ISO_FILES=( "${ISO_FILES[@]}" $TMP_DIR/boot/* )


