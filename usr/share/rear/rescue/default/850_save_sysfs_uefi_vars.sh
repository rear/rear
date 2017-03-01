
# A simplified uefivars replacement

# USING_UEFI_BOOTLOADER empty or 0 means NO UEFI
is_true $USING_UEFI_BOOTLOADER || return

# When the user has specified UEFI_BOOTLOADER in /etc/rear/local.conf use it if exists and is a regular file.
# Double quotes are mandatory here because 'test -f' without any (possibly empty) argument results true:
if test -f "$UEFI_BOOTLOADER" ; then

    # Show to the user a confirmation when his specified UEFI_BOOTLOADER is actually used:
    LogPrint "Using UEFI_BOOTLOADER=$UEFI_BOOTLOADER"

else

    # When UEFI_BOOTLOADER is not specified or when it does not exist or is no regular file
    # try to autodetect what to use as UEFI_BOOTLOADER:
    LogPrint "Autodetecting what to use as UEFI_BOOTLOADER"

    test -d "$VAR_DIR/recovery" || mkdir -p -m 755 $VAR_DIR/recovery
    local uefi_variables_file=$VAR_DIR/recovery/uefi-variables
    rm -f $uefi_variables_file

    local efibootmgr_output=$TMP_DIR/efibootmgr_output
    efibootmgr > "$efibootmgr_output"

    local uefi_dir=""
    local uefi_file=""
    local uefi_var=""
    local efi_data=""
    local efi_attr=""
    local boot_current=""
    local uefi_bootloader_DOS_path=""
    local uefi_bootloader_filename=""
    # depending the directory ends on vars or efivars we need to treat it different
    # see prep/default/320_include_uefi_env.sh how SYSFS_DIR_EFI_VARS is set
    if [ "$SYSFS_DIR_EFI_VARS" = "/sys/firmware/efi/vars" ] ; then

        for uefi_dir in $( ls $SYSFS_DIR_EFI_VARS ) ; do
            uefi_var=$( echo $uefi_dir | cut -d- -f 1 )
            [[ "$uefi_var" = "new_var" ]] && continue
            [[ "$uefi_var" = "del_var" ]] && continue
            efi_data="$( efibootmgr_read_var $uefi_var $efibootmgr_output )"
            [[ -z "$efi_data" ]] && efi_data="$( uefi_read_data $SYSFS_DIR_EFI_VARS/$uefi_dir/data )"
            efi_attr="$( uefi_read_attributes $SYSFS_DIR_EFI_VARS/$uefi_dir/attributes )"
            echo "$uefi_var $efi_attr: $efi_data" >> $uefi_variables_file
        done
        # finding the correct EFI bootloader in use (UEFI_BOOTLOADER=)
        boot_current=$( grep BootCurrent $uefi_variables_file | cut -d: -f2 | awk '{print $1}' ) # 0000
        uefi_bootloader_DOS_path=$( uefi_extract_bootloader $SYSFS_DIR_EFI_VARS/Boot${boot_current}-*/data )

    elif [ "$SYSFS_DIR_EFI_VARS" = "/sys/firmware/efi/efivars" ] ; then

        for uefi_file in $( ls $SYSFS_DIR_EFI_VARS ) ; do
            uefi_var=$( echo $uefi_file | cut -d- -f 1 )
            efi_data="$( efibootmgr_read_var $uefi_var $efibootmgr_output )"
            [[ -z "$efi_data" ]] && efi_data="$( uefi_read_data $SYSFS_DIR_EFI_VARS/$uefi_file )"
            echo "$uefi_var $efi_attr: $efi_data" >> $uefi_variables_file
            #TODO: efi_attr how to extract??
        done
        # finding the correct EFI bootloader in use (UEFI_BOOTLOADER=)
        boot_current=$( grep BootCurrent $uefi_variables_file | cut -d: -f2 | awk '{print $1}' ) # 0000
        uefi_bootloader_DOS_path=$( uefi_extract_bootloader $SYSFS_DIR_EFI_VARS/Boot${boot_current}-* )

    else
        BugError "UEFI variables directory $SYSFS_DIR_EFI_VARS is neither /sys/firmware/efi/vars nor /sys/firmware/efi/efivars (only those are supported by ReaR)"
    fi

    # Replace backslashes with slashes because uefi_bootloader_DOS_path contains path in DOS format:
    UEFI_BOOTLOADER="/boot/efi"$( echo "$uefi_bootloader_DOS_path" | sed -e 's;\\;/;g' )

    # When UEFI_BOOTLOADER is not yet specified or when it does not exist or is no regular file
    # do further autodetection trials:
    test -f "$UEFI_BOOTLOADER" || UEFI_BOOTLOADER=$( find /boot/efi -name 'grub*.efi' | tail -1 )
    # In case we have an elilo bootloader then we might be lucky with next statement:
    test -f "$UEFI_BOOTLOADER" || UEFI_BOOTLOADER=$( find /boot/efi -name 'elilo.efi' | tail -1 )
    # In case we have a 64-bit systemd bootloader not listed in efivars then we might be lucky with next statement:
    test -f "$UEFI_BOOTLOADER" || UEFI_BOOTLOADER=$( find /boot/EFI -name 'BOOTX64.EFI' | tail -1 )
    # If still no valid UEFI_BOOTLOADER was autodetected, try more generic finds in whole /boot with case insensitive filename matching.
    # The user can specify UEFI_BOOTLOADER as a single string or as an array of filename globbing patterns ("$VAR[@]" works also for a single string).
    # On older systems where 'find' does not support '-iname' this does not make autodetection trials really worse because there 'find' just fails.
    for uefi_bootloader_filename in 'grub*.efi' 'elilo.efi' 'BOOTX64.EFI' "${UEFI_BOOTLOADER[@]}" ; do
        test -f "$UEFI_BOOTLOADER" && break || UEFI_BOOTLOADER=$( find /boot -iname "$uefi_bootloader_filename" | tail -1 )
    done

    # Error out when no valid UEFI_BOOTLOADER could be autodetected:
    test -f "$UEFI_BOOTLOADER" || Error "Cannot autodetect what to use as UEFI_BOOTLOADER, you have to manually specify it in $CONFIG_DIR/local.conf"

    # Show to the user what was autodetected as UEFI_BOOTLOADER:
    LogPrint "Using UEFI_BOOTLOADER=$UEFI_BOOTLOADER"

fi

# Save the variables we need in recover mode into the rescue.conf file:
cat - <<EOF >> "$ROOTFS_DIR/etc/rear/rescue.conf"
USING_UEFI_BOOTLOADER=$USING_UEFI_BOOTLOADER
UEFI_BOOTLOADER="$UEFI_BOOTLOADER"
EOF

