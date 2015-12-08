
# for UEFI only we should avoid SElinux relabeling vfat filesystem: /boot/efi

# empty or 0 means using BIOS method
(( USING_UEFI_BOOTLOADER )) || return

# check if $RECOVERY_FS_ROOT/boot/efi is mounted
if ! test -d "$RECOVERY_FS_ROOT/boot/efi" ; then
    Error "Could not find directory $RECOVERY_FS_ROOT/boot/efi"
fi

cat > $RECOVERY_FS_ROOT/etc/selinux/fixfiles_exclude_dirs <<EOF
/boot/efi
/boot/efi(/.*)?
EOF

