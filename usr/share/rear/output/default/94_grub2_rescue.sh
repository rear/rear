# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

### Add the rescue kernel and initrd to the local GRUB Legacy
###

### Only do when explicitely enabled
if [[ ! "$GRUB_RESCUE" =~ ^[yY1] ]]; then
    return
fi

### Only do when system is not using GRUB Legacy
[[ $(type -p grub-probe) || $(type -p grub2-probe) ]] || return

if [ -f /bin/grub-mkpasswd-pbkdf2 ]; then
    grub_binary=$(get_path grub-mkpasswd-pbkdf2)
elif [ -f /usr/bin/grub2-mkpasswd-pbkdf2 ]; then
    grub_binary=$(get_path grub2-mkpasswd-pbkdf2)
else
    StopIfError "ERROR: no binary found for grub-mkpasswd-pbkdf2 or grub2-mkpasswd-pbkdf2"
fi

if [[ -z "$grub_binary" ]]; then
    Log "Could not find grub-mkpasswd-pbkdf2 or grub2-mkpasswd-pbkdf2 binary."
    return
fi

### Use strings as grub --version syncs all disks
#grub_version=$(get_version "grub --version")
grub_version=$(strings $grub_binary | sed -rn 's/^[^0-9\.]*([0-9]+\.[-0-9a-z\.]+).*$/\1/p' | tail -n 1)
if [[ ! "$grub_version" ]]; then
    # only for grub-legacy we make special rear boot entry in menu.lst
    return
fi

[[ -r "$KERNEL_FILE" ]]
StopIfError "Failed to find kernel, updating GRUB2 failed."

[[ -r "$TMP_DIR/initrd.cgz" ]]
StopIfError "Failed to find initrd.cgz, updating GRUB2 failed."

function total_filesize {
    stat --format '%s' $@ 2>&8 | awk 'BEGIN { t=0 } { t+=$1 } END { print t }'
}

available_space=$(df -Pkl /boot | awk 'END { print $4 * 1024 }')
used_space=$(total_filesize /boot/rear-kernel /boot/rear-initrd.cgz)
required_space=$(total_filesize $KERNEL_FILE $TMP_DIR/initrd.cgz)

if (( available_space + used_space < required_space )); then
    LogPrint "WARNING: Not enough disk space available in /boot for GRUB2 rescue image"
    LogPrint "           Required: $(( required_space / 1024 / 1024 )) MiB /" \
             "Available: $(( ( available_space + used_space ) / 1024 / 1024 )) MiB"
    return
fi

if (( USING_UEFI_BOOTLOADER )) ; then
    # set to 1 means using UEFI
    grub_conf="`dirname $UEFI_BOOTLOADER`/grub.cfg"
elif [[ $(type -p grub2-probe) ]]; then
    grub_conf=$(readlink -f /boot/grub2/grub.cfg)
else
    grub_conf=$(readlink -f /boot/grub/grub.cfg)
fi

[[ -w "$grub_conf" ]]
StopIfError "GRUB2 configuration cannot be modified."

if [[ ! "${GRUB_RESCUE_PASSWORD:0:11}" == 'grub.pbkdf2' ]]; then
    StopIfError "GRUB_RESCUE_PASSWORD needs to be set. Run grub2-mkpasswd-pbkdf2 to generate pbkdf2 hash"
fi

if [[ ! -f /etc/grub.d/01_users ]]; then
    echo "#!/bin/sh
cat << EOF
set superusers=\"$GRUB_SUPERUSER\"
password_pbkdf2 $GRUB_SUPERUSER $GRUB_RESCUE_PASSWORD
EOF" > /etc/grub.d/01_users
fi

grub_pass_set=$(tail -n 4 /etc/grub.d/01_users | grep -E "cat|set superusers|password_pbkdf2|EOF" | wc -l)
if [[ $grub_pass_set < 4 ]]; then
    echo "#!/bin/sh
cat << EOF
set superusers=\"$GRUB_SUPERUSER\"
password_pbkdf2 $GRUB_SUPERUSER $GRUB_RESCUE_PASSWORD
EOF" > /etc/grub.d/01_users
fi

grub_super_set=$(grep 'set superusers' /etc/grub.d/01_users | cut -f2 -d '"')
if [[ ! $grub_super_set == $GRUB_SUPERUSER ]]; then
    sed -i "s/set superusers=\"\S*\"/set superusers=\"$GRUB_SUPERUSER\"/" /etc/grub.d/01_users
    sed -i "s/password_pbkdf2\s\S*\s\S*/password_pbkdf2 $GRUB_SUPERUSER $GRUB_RESCUE_PASSWORD/" /etc/grub.d/01_users
fi

grub_enc_password=$(grep "password_pbkdf2" /etc/grub.d/01_users | awk '{print $3}')
if [[ ! $grub_enc_password == $GRUB_RESCUE_PASSWORD ]]; then
    sed -i "s/password_pbkdf2\s\S*\s\S*/password_pbkdf2 $GRUB_SUPERUSER $GRUB_RESCUE_PASSWORD/" /etc/grub.d/01_users
fi


# Ensure 01_users is added to the /boot/grub.d/
if [[ ! -x /etc/grub.d/01_users ]]; then
    chmod 755 /etc/grub.d/01_users
fi

if [[ $( type -f grub2-mkconfig ) ]]; then
    grub2-mkconfig -o $grub_conf
else
    grub-mkconfig -o $grub_conf
fi

awk -f- $grub_conf >$TMP_DIR/grub.cfg <<EOF
/^menuentry \"Relax and Recover\" --class os --users \"\"/ {
    ISREAR=1
    next
}

/^menuentry / {
    ISREAR=0
}

{
    if (ISREAR) {
        next
    }
    print
}

END {
    print "menuentry \"Relax and Recover\" --class os --users \"\" {"
    print "\tset root=\'hd0,msdos1\'"
    print "\tlinux  /rear-kernel $KERNEL_CMDLINE"
    print "\tinitrd /rear-initrd.cgz"
    print "\tpassword_pbkdf2 $GRUB_SUPERUSER $GRUB_RESCUE_PASSWORD"
    print "}"
}
EOF

[[ -s $grub_conf ]]
BugIfError "Modified GRUB2 is empty !"

if ! diff -u $grub_conf $TMP_DIR/grub.cfg >&2; then
    LogPrint "Modifying local GRUB configuration"
    cp -af $v $grub_conf $grub_conf.old >&2
    cat $TMP_DIR/grub.cfg >$grub_conf
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
