
# for UEFI only we should avoid SElinux relabeling vfat filesystem: /boot/efi

# empty or 0 means using BIOS method
is_true $USING_UEFI_BOOTLOADER || return 0

# check if $TARGET_FS_ROOT/boot/efi is mounted
if ! test -d "$TARGET_FS_ROOT/boot/efi" ; then
    Error "Could not find directory $TARGET_FS_ROOT/boot/efi"
fi

cat > $TARGET_FS_ROOT/etc/selinux/fixfiles_exclude_dirs <<EOF
/boot/efi
/boot/efi(/.*)?
EOF

