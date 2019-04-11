
# In conf/default.conf we defined an empty variable USING_UEFI_BOOTLOADER
# This script will try to guess if we're using UEFI or not, and if yes,
# then add all the required executables, kernel modules, etc...
# Most likely, only recent OSes will be UEFI capable, such as SLES11, RHEL6, Ubuntu 12.10, Fedora 18, Arch Linux

# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# By default the variable USING_UEFI_BOOTLOADER is empty which means ReaR will decide (this script)
# except when the variable USING_UEFI_BOOTLOADER has an explicit 'false' value set:
if is_false $USING_UEFI_BOOTLOADER ; then
    # we forced the variable to zero (in local.conf) so we do not want UEFI stuff
    Log "We do not want UEFI capabilities in ReaR (USING_UEFI_BOOTLOADER=0)"
    return
fi
# FIXME: I <jsmeix@suse.de> wonder if ReaR should also decide via the code below
# if the variable USING_UEFI_BOOTLOADER has already an explicit 'true' value set.
# I think if the variable USING_UEFI_BOOTLOADER has an explicit 'true' value set
# but the code below returns before "it is safe to turn on USING_UEFI_BOOTLOADER=1"
# then something is probably wrong because the user wants USING_UEFI_BOOTLOADER
# but the tests in the code below seem to contradict what the user wants
# so that probably ReaR should better abort here with an error and not
# blindly proceed and then fail later in arbitrary unpredictable ways
# cf. https://github.com/rear/rear/issues/801#issuecomment-200353337
# or is it also usually "safe to proceed with USING_UEFI_BOOTLOADER=1"
# when the user has explicitly specified that regardless of the tests below?

# Some distributions don't have a builtin efivars kernel module, so we need to load it.
# Be aware, efivars is not listed with 'lsmod'
modprobe -q efivars

# Next step is checking the presence of UEFI variables directory.
# However, we should first check kernel command line to see whether we hide on purpose the UEFI vars with 'noefi':
SYSFS_DIR_EFI_VARS=
if [[ -d /sys/firmware/efi/vars ]] ; then
    SYSFS_DIR_EFI_VARS=/sys/firmware/efi/vars
elif [[ -d /sys/firmware/efi/efivars ]] ; then
    SYSFS_DIR_EFI_VARS=/sys/firmware/efi/efivars
else
    return 0 # when UEFI is enabled the dir is there
fi

# mount-point: efivarfs on /sys/firmware/efi/efivars type efivarfs (rw,nosuid,nodev,noexec,relatime)
if grep -qw efivars /proc/mounts ; then
    SYSFS_DIR_EFI_VARS=/sys/firmware/efi/efivars
fi

# Next step is case-sensitive checking /boot for case-insensitive /efi directory (we need it):
test "$( find /boot -maxdepth 1 -iname efi -type d )" || return 0

# Next step is to get the EFI (Extensible Firmware Interface) system partition (ESP):
local esp_proc_mounts_line=()
# The output of
#   egrep ' /boot/efi | /boot ' /proc/mounts
# may look like the following examples
# on a openSUSE Leap 15.0 system
#   /dev/sda1 /boot/efi vfat rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro 0 0
# cf. https://github.com/rear/rear/issues/2095#issuecomment-475548960
# or like this on a Debian buster system
#   /dev/sda1 /boot/efi vfat rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 0
# cf. https://github.com/rear/rear/issues/2095#issuecomment-475684942
# and https://github.com/rear/rear/issues/2095#issuecomment-481739166
# The ESP could be mounted on /boot/efi or on /boot.
# First try /boot/efi:
esp_proc_mounts_line=( $( grep ' /boot/efi ' /proc/mounts || echo false ) )
if is_false $esp_proc_mounts_line ; then
    # If nothing is mounted on /boot/efi try /boot:
    esp_proc_mounts_line=( $( grep ' /boot ' /proc/mounts || echo false ) )
    if is_false $esp_proc_mounts_line ; then
        DebugPrint "No EFI system partition found (nothing mounted on /boot/efi or /boot)"
        return
    fi
fi

# The ESP filesystem type must be vfat (under Linux):
if ! test "vfat" = "${esp_proc_mounts_line[2]}" ; then
    DebugPrint "No 'vfat' EFI system partition found (${esp_proc_mounts_line[0]} on ${esp_proc_mounts_line[1]} is type ${esp_proc_mounts_line[2]})"
    return 0
fi

# When we are still here we have a filesystem type 'vfat' mounted on /boot/efi or on /boot.
# In this case we assume what is mounted there actually is a EFI system partition (ESP)
# so we assume it is safe to turn on USING_UEFI_BOOTLOADER=1
DebugPrint "Found EFI system partition ${esp_proc_mounts_line[0]} on ${esp_proc_mounts_line[1]} type ${esp_proc_mounts_line[2]}"
USING_UEFI_BOOTLOADER=1
LogPrint "Using UEFI Boot Loader for Linux (USING_UEFI_BOOTLOADER=1)"

# Remember the ESP device node in VAR_DIR/recovery/bootdisk:
echo "${esp_proc_mounts_line[0]}" >$VAR_DIR/recovery/bootdisk

