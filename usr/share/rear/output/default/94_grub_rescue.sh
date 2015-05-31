# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

### Add the rescue kernel and initrd to the local GRUB Legacy
###

### Only do when explicitely enabled
if [[ ! "$GRUB_RESCUE" =~ ^[yY1] ]]; then
    return
fi

### Only do when system has GRUB Legacy
[[ $(type -p grub-probe) || $(type -p grub2-probe) ]] && return

grub_binary=$(get_path grub)
if [[ -z "$grub_binary" ]]; then
    Log "Could not find grub (legacy) binary."
    return
fi

### Use strings as grub --version syncs all disks
#grub_version=$(get_version "grub --version")
grub_version=$(strings $grub_binary | sed -rn 's/^[^0-9\.]*([0-9]+\.[-0-9a-z\.]+).*$/\1/p' | tail -n 1)
if version_newer "$grub_version" 1.0; then
    # only for grub-legacy we make special rear boot entry in menu.lst 
    return
fi

[[ -r "$KERNEL_FILE" ]]
StopIfError "Failed to find kernel, updating GRUB failed."

[[ -r "$TMP_DIR/initrd.cgz" ]]
StopIfError "Failed to find initrd.cgz, updating GRUB failed."

function total_filesize {
    stat --format '%s' $@ 2>&8 | awk 'BEGIN { t=0 } { t+=$1 } END { print t }'
}

available_space=$(df -Pkl /boot | awk 'END { print $4 * 1024 }')
used_space=$(total_filesize /boot/rear-kernel /boot/rear-initrd.cgz)
required_space=$(total_filesize $KERNEL_FILE $TMP_DIR/initrd.cgz)

if (( available_space + used_space < required_space )); then
    LogPrint "WARNING: Not enough disk space available in /boot for GRUB rescue image"
    LogPrint "           Required: $(( required_space / 1024 / 1024 )) MiB /" \
             "Available: $(( ( available_space + used_space ) / 1024 / 1024 )) MiB"
    return
fi

if (( USING_UEFI_BOOTLOADER )) ; then
    # set to 1 means using UEFI
    # SLES uses elilo instead of grub-efi; we will return if that is the case (and do not add a rear rescue entry)
    [[ "${UEFI_BOOTLOADER##*/}" = "elilo.efi" ]] && return
    grub_conf="`dirname $UEFI_BOOTLOADER`/grub.conf"
else
    grub_conf=$(readlink -f /boot/grub/menu.lst)
fi
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
    cp -af $v $grub_conf $grub_conf.old >&2
    cat $TMP_DIR/menu.lst >$grub_conf
fi

if [[ $(stat -L -c '%d' $KERNEL_FILE) == $(stat -L -c '%d' /boot/) ]]; then
    # Hardlink file, if possible
    cp -pLlf $v $KERNEL_FILE /boot/rear-kernel >&2
elif [[ $(stat -L -c '%s %Y' $KERNEL_FILE) == $(stat -L -c '%s %Y' /boot/rear-kernel 2>&8) ]]; then
    # If existing file has exact same size and modification time, assume the same
    :
else
    # In all other cases, replace
    cp -pLf $v $KERNEL_FILE /boot/rear-kernel >&2
fi
BugIfError "Unable to copy '$KERNEL_FILE' to /boot"

cp -af $v $TMP_DIR/initrd.cgz /boot/rear-initrd.cgz >&2
BugIfError "Unable to copy '$TMP_DIR/initrd.cgz' to /boot"
