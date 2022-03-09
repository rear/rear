
# Only run when GRUB2 is specified to be used as USB bootloader:
test "$USB_BOOTLOADER" = "grub" || return 0

# We assume REAL_USB_DEVICE and RAW_USB_DEVICE are both set by prep/USB/Linux-i386/350_check_usb_disk.sh
[ "$RAW_USB_DEVICE" -a "$REAL_USB_DEVICE" ] || BugError "RAW_USB_DEVICE and REAL_USB_DEVICE are not both set"

LogPrint "Using GRUB2 as USB bootloader for legacy BIOS boot on $RAW_USB_DEVICE (USB_BOOTLOADER='$USB_BOOTLOADER')"

# Choose the right GRUB2 install binary and set the right GRUB2 boot directory
# cf. https://github.com/rear/rear/issues/849 and https://github.com/rear/rear/pull/850
# and error out if there is neither grub-install nor grub2-install:
local grub_install_binary="false"
has_binary grub-install && grub_install_binary="grub-install"
has_binary grub2-install && grub_install_binary="grub2-install"
is_false $grub_install_binary && Error "Cannot install GRUB2 as USB bootloader (neither grub-install nor grub2-install found)"
# Choose the right GRUB2 config depending on what there is on the original system
# (if things are unexpected on the original system using GRUB2 as USB bootloader likely fails)
# so better error out here if there is neither /boot/grub/grub.cfg nor /boot/grub2/grub.cfg
# cf. "Try hard to care about possible errors" in https://github.com/rear/rear/wiki/Coding-Style
local grub_cfg="false"
test -s /boot/grub/grub.cfg && grub_cfg="grub/grub.cfg"
test -s /boot/grub2/grub.cfg && grub_cfg="grub2/grub.cfg"
is_false $grub_cfg && Error "Cannot install GRUB2 as USB bootloader (neither /boot/grub/grub.cfg nor /boot/grub2/grub.cfg found)"

# Verify the GRUB version because only GRUB2 is supported.
# Because substr() for awk did not work as expected for this case here
# 'cut' is used (awk '{print $NF}' prints the last column which is the version).
# Only the first character of the version should be enough (at least for now).
# Example output (on openSUSE Leap 15.2)
# # grub2-install --version
# grub2-install (GRUB2) 2.04
# # grub2-install --version | awk '{print $NF}' | cut -c1
# 2
local grub_version
grub_version=$( $grub_install_binary --version | awk '{print $NF}' | cut -c1 )
test "$grub_version" = "2" || Error "Cannot install GRUB as USB bootloader (only GRUB2 is supported, '$grub_install_binary --version' shows '$grub_version')"

# The $BUILD_DIR/outputfs/$USB_PREFIX directory is needed by subsequent scripts
# like output/USB/Linux-i386/830_copy_kernel_initrd.sh to store kernel and initrd
# and for parts of the syslinux config in 'syslinux.cfg' if syslinux/extlinux is used
# but output/USB/Linux-i386/300_create_extlinux.sh also creates it if missing:
local usb_rear_dir="$BUILD_DIR/outputfs/$USB_PREFIX"
if [ ! -d "$usb_rear_dir" ] ; then
    mkdir -p $v "$usb_rear_dir" || Error "Failed to create USB ReaR dir '$usb_rear_dir'"
fi

# Install and configure GRUB2 as USB bootloader for legacy BIOS boot:
local usb_boot_dir="$BUILD_DIR/outputfs/boot"
if [ ! -d "$usb_boot_dir" ] ; then
    mkdir -p $v "$usb_boot_dir" || Error "Failed to create USB boot dir '$usb_boot_dir'"
fi
DebugPrint "Installing GRUB2 as USB bootloader on $RAW_USB_DEVICE"
$grub_install_binary --boot-directory=$usb_boot_dir --recheck $RAW_USB_DEVICE || Error "Failed to install GRUB2 on $RAW_USB_DEVICE"
# grub[2]-install creates the $BUILD_DIR/outputfs/boot/grub[2] sub-directory that is needed
# to create the GRUB2 config $BUILD_DIR/outputfs/boot/grub[2].cfg in the next step:
DebugPrint "Creating GRUB2 config for legacy BIOS boot as USB bootloader"
test "$USB_DEVICE_BOOT_LABEL" || USB_DEVICE_BOOT_LABEL="REARBOOT"
# We need to set the GRUB environment variable 'root' to the partition device with filesystem label USB_DEVICE_BOOT_LABEL
# because GRUB's default 'root' (or GRUB's 'root' identifcation heuristics) would point to the ramdisk but neither kernel
# nor initrd are located on the ramdisk but on the partition device with filesystem label USB_DEVICE_BOOT_LABEL.
# GRUB2_SEARCH_ROOT_COMMAND is used in the create_grub2_cfg() function:
GRUB2_SEARCH_ROOT_COMMAND="search --no-floppy --set=root --label $USB_DEVICE_BOOT_LABEL"
create_grub2_cfg /$USB_PREFIX/kernel /$USB_PREFIX/$REAR_INITRD_FILENAME > $usb_boot_dir/$grub_cfg || Error "Failed to create $usb_boot_dir/$grub_cfg"
