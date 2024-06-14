# On UEFI systems we need to restore the ESP from the rescue system because
# PPDM can't recover vfat. Therefore we also ensure that the ESP is backed
# up in the first place to the rescue image and that changes in the ESP
# content trigger a new rescue image.

if is_true $RESTORE_ESP_FROM_RESCUE_SYSTEM; then

    test -d /boot/efi ||
        Error "RESTORE_ESP_FROM_RESCUE_SYSTEM is enabled but /boot/efi does not exist"

    CHECK_CONFIG_FILES+=(
        $(find /boot/efi -type f)
    )
    COPY_AS_IS+=(
        /boot/efi
    )
    LogPrint "Storing EFI System Partition in rescue image"
fi
