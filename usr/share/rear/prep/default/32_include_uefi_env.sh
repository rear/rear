# in conf/default.conf we defined an empty variable USING_UEFI_BOOTLOADER
# This script will try to guess if we're using UEFI or not, and if yes,
# then add all the required executables, kernel modules, etc...
# Most likely, only recent OSes will be UEFI capable, such as SLES11, RHEL6, Ubuntu 12.10, Fedora 18

# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# by default the variable USING_UEFI_BOOTLOADER is empty which means rear will decide (this script)
if [[ "$USING_UEFI_BOOTLOADER" = "0" ]]; then
    # we forced the variable to zero (in local.conf) so we do not want UEFI stuff
    Log "We do not want UEFI capabilities in rear (USING_UEFI_BOOTLOADER=0)"
    return
fi

# Some distributions don't have a builtin efivars kernel module, so we need to load it.
# Be aware, efivars is not listed with 'lsmod'
modprobe -q efivars

# next step, is checking the presence of UEFI variables directory
# However, we should first check kernel command line to see whether we hide on purpose the UEFI vars with 'noefi'
SYSFS_DIR_EFI_VARS=
if [[ -d /sys/firmware/efi/vars ]]; then
    SYSFS_DIR_EFI_VARS=/sys/firmware/efi/vars
elif [[ -d /sys/firmware/efi/efivars ]]; then
    SYSFS_DIR_EFI_VARS=/sys/firmware/efi/efivars
else
    return    # when UEFI is enabled the dir is there
fi

# mount-point: efivarfs on /sys/firmware/efi/efivars type efivarfs (rw,nosuid,nodev,noexec,relatime)
if grep -qw efivars /proc/mounts; then
    SYSFS_DIR_EFI_VARS=/sys/firmware/efi/efivars
fi

# next step, is checking /boot/efi directory (we need it)
if [[ ! -d /boot/efi ]]; then
    return    # must be mounted
fi

# next step, check filesystem partition type (vfat?)
UEFI_FS_TYPE=$(awk '/\/boot\/efi/ { print $3 }' /proc/mounts)

# ESP must be type vfat (under Linux)
if [[ "$UEFI_FS_TYPE" != "vfat" ]]; then
    return
fi

# we are still here? Ok, now it is safe to turn on USING_UEFI_BOOTLOADER=1
USING_UEFI_BOOTLOADER=1
LogPrint "Using UEFI Boot Loader for Linux (USING_UEFI_BOOTLOADER=1)"

awk '/\/boot\/efi/ { print $1 }' /proc/mounts >$VAR_DIR/recovery/bootdisk 2>/dev/null
