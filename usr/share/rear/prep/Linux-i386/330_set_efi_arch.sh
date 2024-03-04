
# Set EFI architecture, used as suffix for various files in the ESP
# See https://github.com/rhboot/shim/blob/main/Make.defaults

# Se the variables even if USING_UEFI_BOOTLOADER empty or no explicit 'true' value

case "$REAL_MACHINE" in
    (i686|i586|i386)
        # all these behave exactly like i386.
        EFI_ARCH=ia32
        # argument for grub2-mkstandalone -O ...
        GRUB2_IMAGE_FORMAT=x86_64-efi
        ;;
    (x86_64)
        EFI_ARCH=x64
        GRUB2_IMAGE_FORMAT=i386-efi
        ;;
    (*)
        BugError "Unknown architecture $REAL_MACHINE"
esac

EFI_ARCH_UPPER="${EFI_ARCH^^}"
