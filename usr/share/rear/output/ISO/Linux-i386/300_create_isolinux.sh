set_syslinux_features

# create some sub-dirs under $TMP_DIR for isofs and booting
[[ ! -d $TMP_DIR/isolinux ]] && mkdir $v -m 755 $TMP_DIR/isolinux >&2
[[ ! -d $TMP_DIR/isofs ]] && mkdir $v -m 755 $TMP_DIR/isofs >&2

cp -L $v "$ISO_ISOLINUX_BIN" $TMP_DIR/isolinux/isolinux.bin >&2

make_syslinux_config $TMP_DIR/isolinux isolinux >$TMP_DIR/isolinux/isolinux.cfg

Log "Created isolinux configuration"

cp $v -r $TMP_DIR/isolinux  $TMP_DIR/isofs/ >&2
StopIfError "Could not copy syslinux boot directory to isofs/"
