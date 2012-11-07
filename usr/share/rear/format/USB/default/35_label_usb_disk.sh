case "$ID_FS_TYPE" in

	ext*)
		USB_LABEL="$(e2label ${RAW_USB_DEVICE}1)"
		if [[ "$USB_LABEL" != "REAR-000" ]]; then
			LogPrint "Setting filesystem label to REAR-000"
			e2label ${RAW_USB_DEVICE}1 REAR-000
			StopIfError "Could not label '${RAW_USB_DEVICE}1' with REAR-000"
			USB_LABEL="$(e2label ${RAW_USB_DEVICE}1)"
		fi
		;;
	btrfs)
		USB_LABEL="$(btrfs filesystem label ${RAW_USB_DEVICE}1)"
		if [[ "$USB_LABEL" != "REAR-000" ]]; then
			LogPrint "Setting filesystem label to REAR-000"
			btrfs filesystem label ${RAW_USB_DEVICE}1 REAR-000
			StopIfError "Could not label '${RAW_USB_DEVICE}1' with REAR-000"
			USB_LABEL="$(btrfs filesystem label ${RAW_USB_DEVICE}1)"
		fi
		;;
esac
Log "Device '${RAW_USB_DEVICE}1' has label $USB_LABEL"
