# $answer is filled by 20_check_usb_layout.sh
if [ "$answer" == "Yes" ]; then
	umount $REAL_USB_DEVICE >/dev/null 2>&1
	parted $RAW_USB_DEVICE mkpart primary 0 100%
	StopIfError "Could not create a primary partition on '$REAL_USB_DEVICE'"
	parted $RAW_USB_DEVICE set 1 boot on
	StopIfError "Could not make primary partition boot-able on '$REAL_USB_DEVICE'"

	mkfs.ext3 -L REAR-000 $REAL_USB_DEVICE 1>&8
	StopIfError "Could not format '$REAL_USB_DEVICE' with ext3 layout"
fi
