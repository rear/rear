USB_LABEL="$(e2label ${RAW_USB_DEVICE}1)"
if [[ "$USB_LABEL" != "REAR-000" ]]; then
	LogPrint "Setting filesystem label to REAR-000"
	e2label ${RAW_USB_DEVICE}1 REAR-000
	StopIfError "Could not label '${RAW_USB_DEVICE}1' with REAR-000"
	USB_LABEL="$(e2label ${RAW_USB_DEVICE}1)"
fi
Log "Device '${RAW_USB_DEVICE}1' has label $USB_LABEL"
