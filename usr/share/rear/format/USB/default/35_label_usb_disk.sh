if [[ "$EFI" == "Yes" ]]; then
    ParNr=2
else
    ParNr=1
fi

case "$ID_FS_TYPE" in

	ext*)
		USB_LABEL="$(e2label ${RAW_USB_DEVICE}${ParNr})"
		if [[ "$USB_LABEL" != "REAR-000" ]]; then
			LogPrint "Setting filesystem label to REAR-000"
			e2label ${RAW_USB_DEVICE}${ParNr} REAR-000
			StopIfError "Could not label '${RAW_USB_DEVICE}${ParNr}' with REAR-000"
			USB_LABEL="$(e2label ${RAW_USB_DEVICE}${ParNr})"
		fi
		;;
	btrfs)
		USB_LABEL="$(btrfs filesystem label ${RAW_USB_DEVICE}${ParNr})"
		if [[ "$USB_LABEL" != "REAR-000" ]]; then
			LogPrint "Setting filesystem label to REAR-000"
			btrfs filesystem label ${RAW_USB_DEVICE}${ParNr} REAR-000
			StopIfError "Could not label '${RAW_USB_DEVICE}${ParNr}' with REAR-000"
			USB_LABEL="$(btrfs filesystem label ${RAW_USB_DEVICE}${ParNr})"
		fi
		;;
esac
Log "Device '${RAW_USB_DEVICE}${ParNr}' has label $USB_LABEL"
