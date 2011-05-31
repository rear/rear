# Add the rescue kernel and initrd to the local GRUB Legacy

# Only do when explicitely enabled
if [[ ! "$GRUB_RESCUE" =~ '^[yY1]' ]]; then
    return
fi

# Only do when system has GRUB Legacy
grub_version=$(get_version "grub --version")
if version_newer "$grub_version" 1.0; then
    return
fi

[[ -r "$BUILD_DIR/kernel" ]]
StopIfError "Failed to find kernel, updating GRUB failed."

[[ -r "$BUILD_DIR/initrd.cgz" ]]
StopIfError "Failed to find initrd.cgz, updating GRUB failed."

function total_filesize {
    stat --printf '%s\n' $@ 2>/dev/null | awk 'BEGIN { t=0 } { t+=$1 } END { print t }'
}

available_space=$(df -Pk /boot | awk 'END { print $4 * 1024 }')
used_space=$(total_filesize /boot/rear-kernel /boot/rear-initrd.cgz)
required_space=$(total_filesize $BUILD_DIR/kernel $BUILD_DIR/initrd.cgz)

if (( available_space + used_space < required_space )); then
    LogPrint "WARNING: Not enough disk space available in /boot for GRUB rescue image"
    LogPrint "           Required: $(( required_space / 1024 / 1024 )) MiB /" \
             "Available: $(( ( available_space + used_space ) / 1024 / 1024 )) MiB"
    return
fi

grub_conf=$(readlink -f /boot/grub/menu.lst)
[[ -w "$grub_conf" ]]
StopIfError "GRUB configuration cannot be modified."

if [[ "${GRUB_RESCUE_PASSWORD:0:3}" == '$1$' ]]; then
    GRUB_RESCUE_PASSWORD="--md5 $GRUB_RESCUE_PASSWORD"
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

[[ -s $grub_conf ]]
BugIfError "Mofified GRUB is empty !"

if ! diff -u $grub_conf $TMP_DIR/menu.lst >&2; then
    LogPrint "Modifying local GRUB configuration"
    cp -af $grub_conf $grub_conf.old >&2
    cat $TMP_DIR/menu.lst >$grub_conf
fi

cp -af $BUILD_DIR/kernel /boot/rear-kernel >&2
BugIfError "Unable to copy '$BUILD_DIR/kernel' to /boot"

cp -af $BUILD_DIR/initrd.cgz /boot/rear-initrd.cgz >&2
BugIfError "Unable to copy '$BUILD_DIR/initrd.cgz' to /boot"
