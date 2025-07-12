# The $BUILD_DIR/outputfs/$USB_PREFIX directory is needed by subsequent scripts
# like output/USB/default/830_copy_kernel_initrd.sh to store kernel and initrd
# and for parts of the syslinux config in 'syslinux.cfg' if syslinux/extlinux is used

USB_REAR_DIR="$BUILD_DIR/outputfs/$USB_PREFIX"
if [ ! -d "$USB_REAR_DIR" ] ; then
    mkdir -p $v "$USB_REAR_DIR" || Error "Failed to create USB ReaR dir '$usb_rear_dir'"
fi
