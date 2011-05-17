# Add the rescue kernel and initrd to the current GRUB

# Only do when explicitely enabled
if [[ -z "$GRUB_RESCUE" ]]; then
    return
fi

if [[ ! -r "$BUILD_DIR/kernel" ]]; then
    Error "Failed to find kernel, updating GRUB failed."
fi

if [[ ! -r "$BUILD_DIR/initrd.cgz" ]]; then
    Error "Failed to find initrd.cgz, updating GRUB failed."
fi

cp -av $BUILD_DIR/kernel /boot/rear-kernel >&2
cp -av $BUILD_DIR/initrd.cgz /boot/rear-initrd.cgz >&2

grub_conf=$(readlink -f /boot/grub/menu.lst)
if [[ ! -w "$grub_conf" ]]; then
    Error "GRUB configuration cannot be modified."
fi

awk -f- $grub_conf >$TMP_DIR/menu.lst <<EOF
/^title Relax and Recover/ {
    ISREAR=1
    next
}

/^title / {
    ISREAR=0
}

{
    if (ISREAR) {
        next
    }
    print
}

END {
    print "title Relax and Recover"
    print "\tpassword $GRUB_RESCUE_PASSWORD"
    print "\tkernel /rear-kernel $KERNEL_CMDLINE"
    print "\tinitrd /rear-initrd.cgz"
}
EOF

if [[ ! -s $grub_conf ]]; then
    BugError "Mofified GRUB is empty"
elif ! diff -u $grub_conf $TMP_DIR/menu.lst >&2; then
    LogPrint "Modifying local GRUB configuration"
    cp -av $grub_conf $grub_conf.old >&2
    cat $TMP_DIR/menu.lst >$grub_conf
fi
