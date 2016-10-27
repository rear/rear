#
# check for usb modules and add the required usb modules to MODULES_LOAD
#
# added *hid for SLES9, thanks to Gerhard Weick
#

lsmod=( $(lsmod | cut -d " " -f 1) )

for module in "${lsmod[@]}" ; do
	case "$module" in
		*hid|*hcd|usb*)
			MODULES_LOAD=( "${MODULES_LOAD[@]}" $module )
			;;
	esac
done
