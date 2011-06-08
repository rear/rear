# $answer is filled by 20_check_usb_layout.sh
if [ "$answer" == "Yes" ]; then
	umount $REAL_USB_DEVICE &>/dev/null

	parted $RAW_USB_DEVICE mkpart primary 0 100%
	StopIfError "Could not create a primary partition on '$REAL_USB_DEVICE'"

	parted $RAW_USB_DEVICE set 1 boot on
	StopIfError "Could not make primary partition boot-able on '$REAL_USB_DEVICE'"

	mkfs.ext3 -L REAR-000 $REAL_USB_DEVICE >&8
	StopIfError "Could not format '$REAL_USB_DEVICE' with ext3 layout"

	tune2fs -c 0 -i 0 -o acl,journal_data,journal_data_ordered $REAL_USB_DEVICE >&8
	StopIfError "Failed to change filesystem characteristics on '$REAL_USB_DEVICE'"

fi
