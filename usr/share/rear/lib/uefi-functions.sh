function uefi_read_data {
    # input arg is path/data
    local dt
    dt=$(cat "$1" | hexdump -e '8/1 "%c""\n"' | tr -dc '[:print:]')
    echo $(trim $dt)
}

function uefi_read_attributes {
    # input arg is path/attributes
    local attr=""
    grep -q EFI_VARIABLE_NON_VOLATILE "$1" && attr="${attr}NV,"
    grep -q EFI_VARIABLE_BOOTSERVICE_ACCESS "$1" && attr="${attr}BS,"
    grep -q EFI_VARIABLE_RUNTIME_ACCESS "$1" && attr="${attr}RT"
    attr="(${attr})"
    echo "$attr"
}

function efibootmgr_read_var {
    # input args are $1 (efi var) and $2 (file $TMP_DIR/efibootmgr_output)
    local var
    var=$(grep "$1" $2 | cut -d: -f 2- | cut -d* -f2-)
    echo "$var"
}

function uefi_extract_bootloader {
    # input arg path/data
    local dt
    dt=$(cat "$1" | tail -1 | tr -cd '[:print:]\n' | cut -d\\ -f2-)
    echo "\\$(trim ${dt})"
}

function trim {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

function build_bootx86_efi {
    local gmkimage=""
    if has_binary grub-mkimage ; then
        gmkimage=grub-mkimage
    elif has_binary grub2-mkimage ; then
        # At least SUSE systems use 'grub2' prefixed names for GRUB2 programs:
        gmkimage=grub2-mkimage
    else
        # This build_bootx86_efi function is only called in output/ISO/Linux-i386/250_populate_efibootimg.sh
        # which runs only if UEFI is used so that we simply error out here if we cannot make a bootable EFI image of GRUB2
        # (normally a function should not exit out but return to its caller with a non-zero return code):
        Error "Cannot make bootable EFI image of GRUB2 (neither grub-mkimage nor grub2-mkimage found)"
    fi
    # grub-mkimage needs /usr/lib/grub/x86_64-efi/moddep.lst (cf. https://github.com/rear/rear/issues/1193)
    # and at least on SUSE systems grub2-mkimage needs /usr/lib/grub2/x86_64-efi/moddep.lst (in 'grub2' directory)
    # so that we error out if grub-mkimage or grub2-mkimage would fail when its moddep.lst is missing.
    # Careful: usr/sbin/rear sets nullglob so that /usr/lib/grub*/x86_64-efi/moddep.lst gets empty if nothing matches
    # and 'test -f' succeeds with empty argument so that we cannot use 'test -f /usr/lib/grub*/x86_64-efi/moddep.lst'
    # also 'test -n' succeeds with empty argument but (fortunately/intentionally?) plain 'test' fails with empty argument:
    test /usr/lib/grub*/x86_64-efi/moddep.lst || Error "$gmkimage would not make bootable EFI image of GRUB2 (no /usr/lib/grub*/x86_64-efi/moddep.lst file)"
    # As not all Linux distros have the same GRUB2 modules present we verify what we have (see also https://github.com/rear/rear/pull/2001)
    local grub_module=""
    local grub_modules=""
    for grub_module in part_gpt part_msdos fat ext2 normal chain boot configfile linux linuxefi multiboot jfs iso9660 usb usbms usb_keyboard video udf ntfs all_video gzio efi_gop reboot search test echo btrfs ; do
        test "$( find /usr/lib/grub*/x86_64-efi -type f -name "$grub_module.mod" 2>/dev/null )" && grub_modules="$grub_modules $grub_module"
    done
    if ! $gmkimage $v -O x86_64-efi -c $TMP_DIR/mnt/EFI/BOOT/embedded_grub.cfg -o $TMP_DIR/mnt/EFI/BOOT/BOOTX64.efi -p "/EFI/BOOT" $grub_modules ; then
        Error "Failed to make bootable EFI image of GRUB2 (error during $gmkimage of BOOTX64.efi)"
    fi
}

