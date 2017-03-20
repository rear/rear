# Trying to find systemd-boot + UEFI booted
# Systemd-boot is a UEFI boot manager formerly known as Gummiboot.
# When systemd-boot is available and the system is UEFI booted, there is no longer a syslinux dependency for ReaR.

# Note: USING_UEFI_BOOTLOADER is not yet defined here (will happen at default/320_include_uefi_env.sh)

if [[ -d /sys/firmware/efi/efivars && -f /boot/EFI/systemd/systemd-bootx64.efi || -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi ]]; then
    SYSTEMD_BOOT=1
fi
