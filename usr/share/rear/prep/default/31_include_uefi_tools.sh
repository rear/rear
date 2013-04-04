# in conf/default.conf we defined an empty variable USING_UEFI_BOOTLOADER
# This script will try to guess if we're using UEFI or not, and if yes,
# then add all the required executables, kernel modules, etc...
# Most likely, only recent OSes will be UEFI capable, such as SLES11, RHEL6, Ubuntu 12.10, Fedora 18

# To verify if this kernel has UEFI Runtime Services enabled we check for efivars module
# Be aware, efivars is not listed with 'lsmod'
modprobe -q efivars || return  # if the module is not present no UEFI booting is possible

# next step, is checking the presence of UEFI variables directory
# However, we should first check kernel command line to see whether we hide on purpose the UEFI vars with 'noefi'
SYSFS_DIR_EFI_VARS=
cat /proc/cmdline | grep -q noefi || {    # 'noefi' option not found, so check for the dir itself
    if [ -d /sys/firmware/efi/vars ]; then
        SYSFS_DIR_EFI_VARS=/sys/firmware/efi/vars
    elif [ -d /sys/firmware/efi/efivars ]; then
        SYSFS_DIR_EFI_VARS=/sys/firmware/efi/efivars
    else 
        return    # when UEFI is enabled the dir is there
    fi
    }

# mount-point: efivarfs on /sys/firmware/efi/efivars type efivarfs (rw,nosuid,nodev,noexec,relatime)
mount | grep -q efivarfs && SYSFS_DIR_EFI_VARS=/sys/firmware/efi/efivars

# next step, is checking /boot/efi directory (we need it)
[[ ! -d /boot/efi ]] && return    # must be mounted

# next step, check filesystem partition type (vfat?)
UEFI_FS_TYPE=$(mount | grep -i "/boot/efi" | awk '{print $5}')

[[ "$UEFI_FS_TYPE" != "vfat" ]] && return    # ESP must be type vfat (under Linux)

# we are still here? Ok, now it is safe to turn on USING_UEFI_BOOTLOADER=1
USING_UEFI_BOOTLOADER=1
LogPrint "Using UEFI Boot Loader for Linux (USING_UEFI_BOOTLOADER=1)"

PROGS=( "${PROGS[@]}"
parted
gdisk
efibootmgr
uefivars
dosfsck
dosfslabel
)

MODULES=( "${MODULES[@]}" efivars )
