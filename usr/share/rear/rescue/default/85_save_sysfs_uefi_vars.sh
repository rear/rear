# a simplified uefivars replacement
(( USING_UEFI_BOOTLOADER )) || return    # empty or 0 means NO UEFI

[[ ! -d $VAR_DIR/recovery ]] && mkdir -p -m 755 $VAR_DIR/recovery
rm -f $VAR_DIR/recovery/uefi-variables

EFIBOOTMGR_OUTPUT=$TMP_DIR/efibootmgr_output
efibootmgr > "$EFIBOOTMGR_OUTPUT"

# depending the directory ends on vars or efivars we need to treat it different
if [ "$SYSFS_DIR_EFI_VARS" = "/sys/firmware/efi/vars" ]; then

    for uefi_dir in $(ls $SYSFS_DIR_EFI_VARS)
    do
        uefi_var=$(echo $uefi_dir | cut -d- -f 1)
        [[ "$uefi_var" = "new_var" ]] && continue
        [[ "$uefi_var" = "del_var" ]] && continue
        efi_data="$(efibootmgr_read_var $uefi_var $EFIBOOTMGR_OUTPUT)"
        [[ -z "$efi_data" ]] && efi_data="$(uefi_read_data $SYSFS_DIR_EFI_VARS/$uefi_dir/data)"
        efi_attr="$(uefi_read_attributes $SYSFS_DIR_EFI_VARS/$uefi_dir/attributes)"
        echo "$uefi_var $efi_attr: $efi_data"  >> $VAR_DIR/recovery/uefi-variables
    done
    # finding the correct EFI bootloader in use (UEFI_BOOTLOADER=)
    BootCurrent=$(grep BootCurrent $VAR_DIR/recovery/uefi-variables | cut -d: -f2 | awk '{print $1}')	# 0000
    my_UEFI_BOOTLOADER=$(uefi_extract_bootloader $SYSFS_DIR_EFI_VARS/Boot${BootCurrent}-*/data)

elif [ "$SYSFS_DIR_EFI_VARS" = "/sys/firmware/efi/efivars" ]; then

    for uefi_file in $(ls $SYSFS_DIR_EFI_VARS)
    do
        uefi_var=$(echo $uefi_file | cut -d- -f 1)
        efi_data="$(efibootmgr_read_var $uefi_var $EFIBOOTMGR_OUTPUT)"
        [[ -z "$efi_data" ]] && efi_data="$(uefi_read_data $SYSFS_DIR_EFI_VARS/$uefi_file)"
        echo "$uefi_var $efi_attr: $efi_data"  >> $VAR_DIR/recovery/uefi-variables
        #TODO: efi_attr how to extract??
    done
    # finding the correct EFI bootloader in use (UEFI_BOOTLOADER=)
    BootCurrent=$(grep BootCurrent $VAR_DIR/recovery/uefi-variables | cut -d: -f2 | awk '{print $1}')	# 0000
    my_UEFI_BOOTLOADER=$(uefi_extract_bootloader $SYSFS_DIR_EFI_VARS/Boot${BootCurrent}-*)

else
    BugError "UEFI Variables directory $SYSFS_DIR_EFI_VARS is not what I expected"
fi

# Perhaps we defined UEFI_BOOTLOADER in /etc/rear/local.conf - check this now
if [[ ! -z "${UEFI_BOOTLOADER}" ]]; then
    # right, variable is not empty, but is it a file?
    [[ ! -f ${UEFI_BOOTLOADER} ]] && Error "Cannot find a proper UEFI_BOOTLOADER ($UEFI_BOOTLOADER). 
Please define it in $CONFIG_DIR/local.conf (e.g. UEFI_BOOTLOADER=/boot/efi/EFI/fedora/grubx64.efi)"

else
    # the UEFI_BOOTLOADER contains path in DOS format
    UEFI_BOOTLOADER="/boot/efi"$(echo "$my_UEFI_BOOTLOADER" | sed -e 's;\\;/;g')
    if [[ ! -f ${UEFI_BOOTLOADER} ]]; then
        UEFI_BOOTLOADER=$(find /boot/efi -name "grub*.efi" | tail -1)
    fi
fi

# in case we have an elilo bootloader then we might be lucky with next statements
if [[ ! -f ${UEFI_BOOTLOADER} ]]; then
    UEFI_BOOTLOADER=$(find /boot/efi -name "elilo.efi" | tail -1)
fi

# triple check it
if [[ ! -f ${UEFI_BOOTLOADER} ]]; then

    Error "Cannot find a proper UEFI_BOOTLOADER ($UEFI_BOOTLOADER). 
Please define it in $CONFIG_DIR/local.conf (e.g. UEFI_BOOTLOADER=/boot/efi/EFI/fedora/bootx64.efi)"

else

    Log "Using UEFI_BOOTLOADER=$UEFI_BOOTLOADER"

fi

# save the variables we need in recover mode into the rescue.conf file
cat - <<EOF >> "$ROOTFS_DIR/etc/rear/rescue.conf"
USING_UEFI_BOOTLOADER=$USING_UEFI_BOOTLOADER
UEFI_BOOTLOADER="$UEFI_BOOTLOADER"
EOF

