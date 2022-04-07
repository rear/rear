# create_local_efi_dir.sh script
# useful for testing the rescue boot procedure on local disk
# instead of burning an ISO image to CD to boot from
# Lives under /boot/efi/efi/rear
# CREATE_LOCAL_EFI_DIR=true is set in usr/share/rear/conf/Linux-ia64.conf
# but not mentioned in default.conf - nevertheless the user may set it to false:
is_true $CREATE_LOCAL_EFI_DIR || return 0
test -d /boot/efi/efi/rear || mkdir -p /boot/efi/efi/rear
cp $v $TMP_DIR/mnt/boot/* /boot/efi/efi/rear/
LogPrint "Populated local EFI boot directory /boot/efi/efi/rear (CREATE_LOCAL_EFI_DIR is true)"
