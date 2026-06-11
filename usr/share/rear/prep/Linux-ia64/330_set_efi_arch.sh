
# Set EFI architecture, used as suffix for various files in the ESP
# See https://github.com/rhboot/shim/blob/main/Make.defaults

# Set the variables even if USING_UEFI_BOOTLOADER empty or no explicit 'true' value
# cf. prep/Linux-i386/330_set_efi_arch.sh

EFI_ARCH=ia64
# argument for grub2-mkstandalone -O ...
GRUB2_IMAGE_FORMAT=ia64-efi

EFI_ARCH_UPPER="${EFI_ARCH^^}"
