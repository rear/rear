# 940_grub_rescue.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

### Add the rescue kernel and initrd to the local GRUB Legacy
###

# With EFI_STUB enabled there will be no Grub entry.
is_true "$EFI_STUB" && return 0

# Only do it when explicitly enabled:
is_true "$GRUB_RESCUE" || return 0

### Only do when system has GRUB Legacy
[[ $(type -p grub-probe) || $(type -p grub2-probe) ]] && return

grub_binary=$(get_path grub)
if [[ -z "$grub_binary" ]]; then
    Log "Could not find grub (legacy) binary."
    return
fi

# Use strings because "grub --version" would sync all disks
# cf. the get_version function in lib/layout-functions.sh
grub_version=$(strings $grub_binary | sed -rn 's/^[^0-9\.]*([0-9]+\.[-0-9a-z\.]+).*$/\1/p' | tail -n 1)
if version_newer "$grub_version" 1.0; then
    # only for grub-legacy we make special ReaR boot entry in menu.lst
    return
fi

test -r "$KERNEL_FILE" || Error "Failed to find kernel '$KERNEL_FILE', updating GRUB failed."

test -r "$TMP_DIR/$REAR_INITRD_FILENAME" || Error "Failed to find initrd '$REAR_INITRD_FILENAME', updating GRUB failed."

function total_filesize {
    stat --format '%s' "$@" 2>/dev/null | awk 'BEGIN { t=0 } { t+=$1 } END { print t }'
}

available_space=$(df -Pkl /boot | awk 'END { print $4 * 1024 }')
used_space=$(total_filesize /boot/rear-kernel /boot/rear-$REAR_INITRD_FILENAME)
required_space=$(total_filesize $KERNEL_FILE $TMP_DIR/$REAR_INITRD_FILENAME)

if (( available_space + used_space < required_space )) ; then
    required_MiB=$(( required_space / 1024 / 1024 ))
    available_MiB=$(( ( available_space + used_space ) / 1024 / 1024 ))
    Error "Not enough disk space available in /boot for GRUB rescue image. Required: $required_MiB MiB. Available: $available_MiB MiB."
fi

if is_true $USING_UEFI_BOOTLOADER ; then
    # set to 1 means using UEFI
    # SLES uses elilo instead of grub-efi; we will return if that is the case (and do not add a ReaR rescue entry)
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
/^title Relax-and-Recover/ {
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
    print "title Relax-and-Recover"
    print "\tpassword $GRUB_RESCUE_PASSWORD"
    print "\tkernel /rear-kernel $KERNEL_CMDLINE"
    print "\tinitrd /rear-$REAR_INITRD_FILENAME"
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
    cp -pLlf $v $KERNEL_FILE /boot/rear-kernel || BugError "Failed to hardlink '$KERNEL_FILE' to /boot/rear-kernel"
elif [[ $(stat -L -c '%s %Y' $KERNEL_FILE) == $(stat -L -c '%s %Y' /boot/rear-kernel 2>/dev/null) ]]; then
    # If existing file has exact same size and modification time, assume the same
    :
else
    # In all other cases, replace
    cp -pLf $v $KERNEL_FILE /boot/rear-kernel || BugError "Failed to copy '$KERNEL_FILE' to /boot/rear-kernel"
fi

cp -af $v $TMP_DIR/$REAR_INITRD_FILENAME /boot/rear-$REAR_INITRD_FILENAME || BugError "Failed to copy '$TMP_DIR/$REAR_INITRD_FILENAME' to '/boot/rear-$REAR_INITRD_FILENAME'"

