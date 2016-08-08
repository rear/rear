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
    local gmkimage
    if has_binary grub-mkimage; then
        gmkimage=grub-mkimage
    elif has_binary grub2-mkimage; then
        gmkimage=grub2-mkimage
    else
        Log "Did not find grub-mkimage (cannot build bootx86.efi)"
        return
    fi
    $gmkimage $v -O x86_64-efi -c $TMP_DIR/mnt/EFI/BOOT/embedded_grub.cfg -o $TMP_DIR/mnt/EFI/BOOT/BOOTX64.efi -p "/EFI/BOOT" part_gpt part_msdos fat ext2 normal chain boot configfile linux linuxefi multiboot jfs iso9660 usb usbms usb_keyboard video udf ntfs all_video gzio efi_gop reboot search test echo btrfs
    StopIfError "Error occurred during $gmkimage of BOOTX64.efi"
}
