USB_LABEL="$(e2label $REAL_USB_DEVICE)"
if [[ "$USB_LABEL" != "REAR-000" ]]; then
	e2label $REAL_USB_DEVICE REAR-000
	StopIfError "Could not label '$REAL_USB_DEVICE' with REAR-000"
	USB_LABEL="$(e2label $REAL_USB_DEVICE)"
fi
Log "Device '$REAL_USB_DEVICE' has label $USB_LABEL"
