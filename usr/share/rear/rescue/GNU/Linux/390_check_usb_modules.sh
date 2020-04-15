#
# check for usb modules and add the required usb modules to MODULES_LOAD
# added *hid for SLES9, thanks to Gerhard Weick
#

local module
for module in $( lsmod | cut -d " " -f 1 ) ; do
	case "$module" in
		*hid|*hcd|usb*)
			MODULES_LOAD+=( $module )
			;;
	esac
done
