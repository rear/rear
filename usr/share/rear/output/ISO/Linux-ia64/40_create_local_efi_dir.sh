# create_local_efi_dir.sh script
# useful for testing the rescue boot procedure on local disk instead of
# burning an ISO image to CD to boot from
# Lives under /boot/efi/efi/rear
# set the variable in config file /etc/rear/Linux-ia64.conf
[ CREATE_LOCAL_EFI_DIR = false ] && return
[ ! -d /boot/efi/efi/rear ] && mkdir -p /boot/efi/efi/rear
cp $v $TMP_DIR/mnt/boot/* /boot/efi/efi/rear/ >&2
Log "Populated the local EFI boot directory /boot/efi/efi/rear"
