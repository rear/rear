
# Only run when GRUB2 is specified to be used as USB bootloader:
test "$USB_BOOTLOADER" = "grub" || return 0

DebugPrint "Installing GRUB2 as USB bootloader (USB_BOOTLOADER='$USB_BOOTLOADER')"

# Choose right GRUB2 install binary
# cf. https://github.com/rear/rear/issues/849
# and error out if there is neither grub-install nor grub2-install:
local grub_install_binary="false"
has_binary grub-install && grub_install_binary="grub-install"
has_binary grub2-install && grub_install_binary="grub2-install"
is_false $grub_install_binary && Error "Cannot install GRUB2 as USB bootloader (neither grub-install nor grub2-install found)"

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

# We assume REAL_USB_DEVICE and RAW_USB_DEVICE are both set by prep/USB/Linux-i386/350_check_usb_disk.sh
[ "$RAW_USB_DEVICE" -a "$REAL_USB_DEVICE" ] || BugError "RAW_USB_DEVICE and REAL_USB_DEVICE are not both set"

# TODO: Provide a comment here that tells why usb_rear_dir is needed:
local usb_rear_dir="$BUILD_DIR/outputfs/$USB_PREFIX"
if [ ! -d "$usb_rear_dir" ] ; then
    mkdir -p $v "$usb_rear_dir" || Error "Could not create USB ReaR dir '$usb_rear_dir'"
fi

# Install and configure GRUB2 as USB bootloader:
local usb_boot_dir="$BUILD_DIR/outputfs/boot"
if [ ! -d "$usb_boot_dir" ] ; then
    mkdir -p $v "$usb_boot_dir" || Error "Could not create USB boot dir '$usb_boot_dir'"
fi
$grub_install_binary --boot-directory=$usb_boot_dir --recheck $RAW_USB_DEVICE || Error "Failed to install GRUB2 on $RAW_USB_DEVICE"
Log "Configuring GRUB2 as USB bootloader for legacy boot"
# We need to explicitly set $root variable to boot label (currently "REAR-BOOT") in GRUB2
# because default $root would point to ramdisk, where kernel and initrd are NOT present.
# grub2_set_usb_root is a global variable that is used in the create_grub2_cfg() function:
grub2_set_usb_root="search --no-floppy --set=root --label REAR-BOOT"
# Create config for GRUB2:
Log "Creating GRUB2 config as USB bootloader"
create_grub2_cfg /$USB_PREFIX/kernel /$USB_PREFIX/$REAR_INITRD_FILENAME > $usb_boot_dir/grub/grub.cfg
