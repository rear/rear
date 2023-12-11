# To be executed after output/default/100_mount_output_path.sh
# Check whether the the USB directory is a moutpoint.
# We need it to be a mountpoint, with a block device mounted there,
# because later tasks (like installing bootloader) depend on it.
# output/default/100_mount_output_path.sh should have mounted it.

# Usually one would use a usb:// URL for OUTPUT=USB. Otherwise
# one would have to use a URL that causes the output disk to be mounted
# at $BUILD_DIR/outputfs. file:// does not satisfy this requirement
# (see below).

local usbdev
local scheme

scheme="$( url_scheme $OUTPUT_URL )"

if ! mountpoint $BUILD_DIR/outputfs ; then
    # It should be possible to support OUTPUT_URL=file://...,
    # the user whould have to mount the USB manually.
    # For this to work, one would need to eliminate all the hardcoded
    # $BUILD_DIR/outputfs in the OUTPUT=USB code, incl. the one above
    # (replace by url_path $OUTPUT_URL).
    # USB_DEVICE would need to be properly set as well.
    if [ "$scheme" == file ] ; then
        LogPrintError "file:// OUTPUT_URL is currently unsupported for OUTPUT=USB, use usb://"
    fi
    Error "OUTPUT_URL '$OUTPUT_URL' is not mounted at $BUILD_DIR/outputfs"
fi

if usbdev="$(findmnt -funo SOURCE --target $BUILD_DIR/outputfs)" ; then
    if [ -z "$usbdev" ] ; then
        LogPrintError "'findmnt -funo SOURCE --target $BUILD_DIR/outputfs' returned an empty string"
        Error "Could not check that OUTPUT_URL '$OUTPUT_URL' refers to a block device mounted at $BUILD_DIR/outputfs"
    fi
    # It needs to be a disk-based filesystem (not e.g. NFS)
    # as OUTPUT=USB basically means "disk" (not necessarily USB).
    if ! [ -b "$usbdev" ] ; then
        LogPrintError "OUTPUT=USB needs OUTPUT_URL to refer to a block device."
        if [ "$scheme" != usb ] ; then
            LogPrintError "Use the usb:// scheme for OUTPUT_URL"
        fi
        Error "OUTPUT_URL '$OUTPUT_URL' refers to mounted '$usbdev' which is not a block device"
    fi
else
    # needs to be in the "else" branch. "! usbdev=$(findmnt ...)" would clobber
    # the exit status of "findmnt" and $? would become useless.
    LogPrintError "'findmnt -funo SOURCE --target $BUILD_DIR/outputfs' failed with exit code $?"
    Error "Failed to check that OUTPUT_URL '$OUTPUT_URL' refers to a block device mounted at $BUILD_DIR/outputfs"
fi
