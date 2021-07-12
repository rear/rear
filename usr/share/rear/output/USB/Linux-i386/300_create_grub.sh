# only run for grub
# set nocasematch option
shopt -s nocasematch
if [ -z $USB_BOOTLOADER ] && [[ ! $USB_BOOTLOADER =~ grub ]]; then
    return 0
fi

# we assume that REAL_USB_DEVICE and RAW_USB_DEVICE are both set from the script
# in prep/USB/Linux-i386/350_check_usb_disk.sh

[ "$RAW_USB_DEVICE" -a "$REAL_USB_DEVICE" ]
BugIfError "RAW_USB_DEVICE and REAL_USB_DEVICE should be already set"

USB_REAR_DIR="$BUILD_DIR/outputfs/$USB_PREFIX"
if [ ! -d "$USB_REAR_DIR" ]; then
    mkdir -p $v "$USB_REAR_DIR" >/dev/null
    StopIfError "Could not create USB ReaR dir [$USB_REAR_DIR] !"
fi

USB_BOOT_DIR="$BUILD_DIR/outputfs/boot"
if [ ! -d "$USB_BOOT_DIR" ]; then
    mkdir -p $v "$USB_BOOT_DIR" >/dev/null
    StopIfError "Could not create USB boot dir [$USB_BOOT_DIR] !"
fi

# Hope this assumption is not wrong ...
if has_binary grub-install grub2-install; then

    # Choose right grub binary
    # Issue #849
    if has_binary grub2-install; then
        Log "using grub2 binary"
        NUM=2
    fi

    GRUB_INSTALL=grub${NUM}-install

    # install
    Log "installing grub..."
    $GRUB_INSTALL --boot-directory=${USB_BOOT_DIR} --recheck $RAW_USB_DEVICE
    StopIfError "Could not install grub on $RAW_USB_DEVICE !"

    # What version of grub are we using
    # substr() for awk did not work as expected for this reason cut was used
    # First charecter should be enough to identify grub version
    grub_version=$($GRUB_INSTALL --version | awk '{print $NF}' | cut -c1-1)

    case ${grub_version} in
        0)
            BugError "grub 0.97 not supported"
        ;;
        2)
            Log "Configuring grub 2.0 for legacy boot"
            # We need to explicitly set $root variable to boot label
            # (currently "REAR-BOOT") in Grub because default $root would
            # point to memdisk, where kernel and initrd are NOT present.
            # Variable grub2_set_usb_root will be used in later call of
            # create_grub2_cfg().
            grub2_set_usb_root="search --no-floppy --set=root --label REAR-BOOT"

            # Create config for grub 2.0
            Log "creating new grub config..."
            create_grub2_cfg /$USB_PREFIX/kernel /$USB_PREFIX/$REAR_INITRD_FILENAME > ${USB_BOOT_DIR}/grub/grub.cfg
        ;;
        *)
            BugError "Neither grub 0.97 nor 2.0"
        ;;
    esac

fi
