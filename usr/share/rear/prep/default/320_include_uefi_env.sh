# in conf/default.conf we defined an empty variable USING_UEFI_BOOTLOADER
# This script will try to guess if we're using UEFI or not, and if yes,
# then add all the required executables, kernel modules, etc...
# Most likely, only recent OSes will be UEFI capable, such as SLES11, RHEL6, Ubuntu 12.10, Fedora 18, Arch Linux

# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# by default the variable USING_UEFI_BOOTLOADER is empty which means ReaR will decide (this script)
# except when the variable USING_UEFI_BOOTLOADER has an explicit 'false' value set:
if is_false $USING_UEFI_BOOTLOADER ; then
    # we forced the variable to zero (in local.conf) so we do not want UEFI stuff
    Log "We do not want UEFI capabilities in ReaR (USING_UEFI_BOOTLOADER=0)"
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
    if [[ $USING_UEFI_BOOTLOADER == 1 ]]; then
        Error "USING_UEFI_BOOTLOADER = 1 but there is no /sys/firmware/efi/vars neither /sys/firmware/efi/efivars" # abort
    fi
    return    # when UEFI is enabled the dir is there
fi

# mount-point: efivarfs on /sys/firmware/efi/efivars type efivarfs (rw,nosuid,nodev,noexec,relatime)
if grep -qw efivars /proc/mounts; then
    SYSFS_DIR_EFI_VARS=/sys/firmware/efi/efivars
fi

# next step, is case-sensitive checking /boot for case-insensitive /efi directory (we need it)
# FIXME: I <2010@probackup.nl> wonder whether it is necessary to have this check here because
# an identical check is already there in 310_include_uefi_tools.sh 
# and the next step "check filesystem partition type (vfat?)" has near identical logic.
if [[ ! -d /boot/[eE][fF][iI] ]]; then
    if [[ $USING_UEFI_BOOTLOADER == 1 ]]; then
        Error "USING_UEFI_BOOTLOADER = 1 but there is no /boot/efi neither /boot/EFI directory" # abort
    fi
    return # skip
fi

local esp_mount_point=""

# next step, check filesystem partition type (vfat?)
esp_mount_point='/\/boot\/efi/'
UEFI_FS_TYPE=$(awk $esp_mount_point' { print $3 }' /proc/mounts)
# if not mounted at /boot/efi, try /boot
if [[ -z "$UEFI_FS_TYPE" ]]; then
    esp_mount_point='/\/boot/'
    UEFI_FS_TYPE=$(awk $esp_mount_point' { print $3 }' /proc/mounts)
fi

# ESP must be type vfat (under Linux)
if [[ "$UEFI_FS_TYPE" != "vfat" ]]; then
    if [[ $USING_UEFI_BOOTLOADER == 1 ]]; then
        Error "USING_UEFI_BOOTLOADER = 1 but there is no VFAT formatted file system mounted at /boot/efi neither /boot" # abort
    fi
    return
fi

# we are still here? Ok, now it is safe to turn on USING_UEFI_BOOTLOADER=1
USING_UEFI_BOOTLOADER=1
LogPrint "Using UEFI Boot Loader for Linux (USING_UEFI_BOOTLOADER=1)"

awk $esp_mount_point' { print $1 }' /proc/mounts >$VAR_DIR/recovery/bootdisk 2>/dev/null
