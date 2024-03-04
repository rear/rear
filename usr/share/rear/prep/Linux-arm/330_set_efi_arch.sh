
# Set EFI architecture, used as suffix for various files in the ESP
# See https://github.com/rhboot/shim/blob/main/Make.defaults

# Se the variables even if USING_UEFI_BOOTLOADER empty or no explicit 'true' value

case "$REAL_MACHINE" in
    (arm64|aarch64)
        EFI_ARCH=aa64
        ;;
    (arm*)
        EFI_ARCH=arm
        ;;
    (*)
        BugError "Unknown architecture $REAL_MACHINE"
esac

EFI_ARCH_UPPER="${EFI_ARCH^^}"
