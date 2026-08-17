# Mount the ReaR initrd overlay from the ISO/USB device or download it
# from a PXE server. This must run before udev starts (before
# 40-start-udev-or-load-modules.sh) so that all kernel modules and
# firmware are available for hardware detection.

# Skip if already loaded (prevent double execution)
test -e /tmp/.rear-overlay-loaded && { return 0 2>/dev/null; exit 0; }

# Parse rear_overlay= from kernel cmdline (used by PXE and GRUB_RESCUE)
REAR_OVERLAY_CMDLINE=""
for param in $(cat /proc/cmdline) ; do
    case "$param" in
        (rear_overlay=*) REAR_OVERLAY_CMDLINE="${param#rear_overlay=}" ;;
    esac
done

# If rear_overlay= is a UUID:path (GRUB_RESCUE), override the output method
if test "${REAR_OVERLAY_CMDLINE#UUID=}" != "$REAR_OVERLAY_CMDLINE" ; then
    REAR_OVERLAY_OUTPUT="GRUB"
    REAR_OVERLAY_MODE="copy"
    REAR_OVERLAY_GRUB_BOOT_UUID="${REAR_OVERLAY_CMDLINE#UUID=}"
    REAR_OVERLAY_GRUB_BOOT_UUID="${REAR_OVERLAY_GRUB_BOOT_UUID%%:*}"
    REAR_OVERLAY_GRUB_PATH="${REAR_OVERLAY_CMDLINE#*:}"
    REAR_OVERLAY_FILENAME="${REAR_OVERLAY_GRUB_PATH##*/}"
elif test -s /etc/rear-overlay.conf ; then
    source /etc/rear-overlay.conf
else
    { return 0 2>/dev/null; exit 0; }
fi

# Load virtual/pseudo modules that udev cannot auto-detect (no hardware modalias)
modprobe loop 2>/dev/null
modprobe squashfs 2>/dev/null
modprobe overlay 2>/dev/null

# Use udev to auto-detect hardware and load the matching drivers from the
# initramfs. The pack stage already selected the essential modules for the
# output method (storage for ISO/USB, network for PXE), so udev will only
# load what is available and what matches actual hardware.
echo "Starting udev to detect hardware for ReaR initrd overlay access ..."
udevd --daemon 2>/dev/null
udevadm trigger --action=add 2>/dev/null
echo -n "Waiting for udev ... "
udevadm settle --timeout=30 2>/dev/null
echo "done."

case "$REAR_OVERLAY_OUTPUT" in
    (ISO)

        echo "Searching for ReaR ISO device ..."
        REAR_ISO_DEVICE=""
        for dev in /dev/sr[0-9]* /dev/cd[0-9]* ; do
            test -b "$dev" || continue
            mkdir -p /mnt/rear-iso
            if mount -t iso9660 -o ro "$dev" /mnt/rear-iso 2>/dev/null ; then
                if test -f "/mnt/rear-iso/isolinux/$REAR_OVERLAY_FILENAME" ; then
                    REAR_ISO_DEVICE="$dev"
                    break
                fi
                umount /mnt/rear-iso
            fi
        done

        if test -z "$REAR_ISO_DEVICE" ; then
            echo "WARNING: Could not find ReaR ISO with ReaR initrd overlay."
            echo "Some essential kernel modules and/or firmwares may be missing."
            rmdir /mnt/rear-iso 2>/dev/null
            { return 0 2>/dev/null; exit 0; }
        fi

        echo "Found ReaR ISO on $REAR_ISO_DEVICE"
        echo "Mounting overlay $REAR_OVERLAY_FILENAME ..."
        mkdir -p /mnt/rear-overlay
        if ! mount -t squashfs -o ro "/mnt/rear-iso/isolinux/$REAR_OVERLAY_FILENAME" /mnt/rear-overlay ; then
            echo "WARNING: Failed to mount ReaR initrd overlay. Continuing without it."
            umount /mnt/rear-iso
            rmdir /mnt/rear-overlay /mnt/rear-iso 2>/dev/null
            { return 0 2>/dev/null; exit 0; }
        fi
        ;;

    (USB)
        echo "Searching for ReaR USB device (label $REAR_OVERLAY_USB_LABEL) ..."
        REAR_USB_DEVICE=""
        # Try by-label first, then scan sd* devices
        if test -b "/dev/disk/by-label/$REAR_OVERLAY_USB_LABEL" ; then
            REAR_USB_DEVICE="/dev/disk/by-label/$REAR_OVERLAY_USB_LABEL"
        else
            for dev in /dev/sd[a-z][0-9]* /dev/vd[a-z][0-9]* ; do
                test -b "$dev" || continue
                mkdir -p /mnt/rear-usb
                if mount -o ro "$dev" /mnt/rear-usb 2>/dev/null ; then
                    if test -f "/mnt/rear-usb/$REAR_OVERLAY_USB_PREFIX/$REAR_OVERLAY_FILENAME" ; then
                        REAR_USB_DEVICE="$dev"
                        umount /mnt/rear-usb
                        break
                    fi
                    umount /mnt/rear-usb
                fi
            done
        fi

        if test -z "$REAR_USB_DEVICE" ; then
            echo "WARNING: Could not find ReaR USB device with ReaR initrd overlay."
            echo "Some essential kernel modules and/or firmwares may be missing."
            rmdir /mnt/rear-usb 2>/dev/null
            { return 0 2>/dev/null; exit 0; }
        fi

        echo "Found ReaR USB device $REAR_USB_DEVICE"
        mkdir -p /mnt/rear-usb
        if ! mount -o ro "$REAR_USB_DEVICE" /mnt/rear-usb ; then
            echo "WARNING: Failed to mount USB device. Continuing without ReaR initrd overlay."
            rmdir /mnt/rear-usb 2>/dev/null
            { return 0 2>/dev/null; exit 0; }
        fi

        echo "Mounting overlay $REAR_OVERLAY_FILENAME ..."
        mkdir -p /mnt/rear-overlay
        if ! mount -t squashfs -o ro "/mnt/rear-usb/$REAR_OVERLAY_USB_PREFIX/$REAR_OVERLAY_FILENAME" /mnt/rear-overlay ; then
            echo "WARNING: Failed to mount ReaR initrd overlay. Continuing without it."
            umount /mnt/rear-usb
            rmdir /mnt/rear-overlay /mnt/rear-usb 2>/dev/null
            { return 0 2>/dev/null; exit 0; }
        fi
        ;;

    (GRUB)
        echo "Mounting boot partition (UUID=$REAR_OVERLAY_GRUB_BOOT_UUID) ..."
        mkdir -p /mnt/rear-boot
        if ! mount -o ro UUID="$REAR_OVERLAY_GRUB_BOOT_UUID" /mnt/rear-boot ; then
            echo "WARNING: Failed to mount boot partition. Continuing without ReaR initrd overlay."
            rmdir /mnt/rear-boot 2>/dev/null
            { return 0 2>/dev/null; exit 0; }
        fi

        echo "Mounting overlay $REAR_OVERLAY_FILENAME ..."
        mkdir -p /mnt/rear-overlay
        if ! mount -t squashfs -o ro "/mnt/rear-boot/$REAR_OVERLAY_GRUB_PATH" /mnt/rear-overlay ; then
            echo "WARNING: Failed to mount ReaR initrd overlay. Continuing without it."
            umount /mnt/rear-boot
            rmdir /mnt/rear-overlay /mnt/rear-boot 2>/dev/null
            { return 0 2>/dev/null; exit 0; }
        fi
        ;;

    (PXE)
        # Bring up the network using the auto-generated setup scripts
        # These handle both static IP and DHCP configurations
        echo "Configuring network for overlay download ..."
        if test -s /etc/scripts/system-setup.d/60-network-devices.sh ; then
            source /etc/scripts/system-setup.d/60-network-devices.sh
        fi
        if test -s /etc/scripts/system-setup.d/62-routing.sh ; then
            source /etc/scripts/system-setup.d/62-routing.sh
        fi
        # If DHCP is configured, start dhclient
        if is_true $USE_DHCLIENT 2>/dev/null ; then
            if test -s /etc/scripts/system-setup.d/58-start-dhclient.sh ; then
                source /etc/scripts/system-setup.d/58-start-dhclient.sh
            fi
        fi

        # Use the overlay URL parsed from kernel command line
        rear_overlay_url="$REAR_OVERLAY_CMDLINE"

        if test -z "$rear_overlay_url" ; then
            echo "WARNING: No rear_overlay= kernel parameter found for ReaR initrd overlay."
            echo "Some essential kernel modules and/or firmwares may be missing."
            { return 0 2>/dev/null; exit 0; }
        fi

        echo "Downloading overlay from $rear_overlay_url ..."
        mkdir -p /tmp
        if ! curl -s -f -o "/tmp/$REAR_OVERLAY_FILENAME" "$rear_overlay_url" ; then
            echo "WARNING: Failed to download ReaR initrd overlay. Continuing without it."
            { return 0 2>/dev/null; exit 0; }
        fi

        echo "Mounting overlay $REAR_OVERLAY_FILENAME ..."
        mkdir -p /mnt/rear-overlay
        if ! mount -t squashfs -o ro "/tmp/$REAR_OVERLAY_FILENAME" /mnt/rear-overlay ; then
            echo "WARNING: Failed to mount ReaR initrd overlay. Continuing without it."
            rm -f "/tmp/$REAR_OVERLAY_FILENAME"
            { return 0 2>/dev/null; exit 0; }
        fi
        ;;

    (*)
        echo "WARNING: Unknown ReaR initrd overlay output type '$REAR_OVERLAY_OUTPUT'."
        { return 0 2>/dev/null; exit 0; }
        ;;
esac

# Apply the overlay content using the configured mode
case "$REAR_OVERLAY_MODE" in
    (mount)
        echo "Setting up overlayfs mounts (overlay stays mounted) ..."

        if test -d /mnt/rear-overlay/usr/lib/firmware ; then
            mkdir -p /tmp/overlay-work/firmware/upper /tmp/overlay-work/firmware/work
            mount -t overlay overlay \
                -o lowerdir=/mnt/rear-overlay/usr/lib/firmware:/usr/lib/firmware,upperdir=/tmp/overlay-work/firmware/upper,workdir=/tmp/overlay-work/firmware/work \
                /usr/lib/firmware
        fi

        if test -d /mnt/rear-overlay/usr/lib/modules ; then
            mkdir -p /tmp/overlay-work/modules/upper /tmp/overlay-work/modules/work
            mount -t overlay overlay \
                -o lowerdir=/mnt/rear-overlay/usr/lib/modules:/usr/lib/modules,upperdir=/tmp/overlay-work/modules/upper,workdir=/tmp/overlay-work/modules/work \
                /usr/lib/modules
        fi
        ;;
    (*)
        echo "Loading overlay content into rescue system ..."
        ( cd /mnt/rear-overlay && tar cf - . ) | ( cd / && tar xf - )

        echo "Cleaning up overlay mounts ..."
        umount /mnt/rear-overlay
        rmdir /mnt/rear-overlay 2>/dev/null
        case "$REAR_OVERLAY_OUTPUT" in
            (ISO)
                umount /mnt/rear-iso
                rmdir /mnt/rear-iso 2>/dev/null
                ;;
            (USB)
                umount /mnt/rear-usb
                rmdir /mnt/rear-usb 2>/dev/null
                ;;
            (PXE)
                rm -f "/tmp/$REAR_OVERLAY_FILENAME"
                ;;
            (GRUB)
                umount /mnt/rear-boot
                rmdir /mnt/rear-boot 2>/dev/null
                ;;
        esac
        ;;
esac

# Regenerate module dependencies with the full module set
depmod -a 2>/dev/null

# Retrigger udev so it can detect hardware that needs modules from the overlay
echo -n "Re-triggering udev with full module set ... "
udevadm trigger --action=add 2>/dev/null
udevadm settle --timeout=30 2>/dev/null
echo "done."

# Stop udev - the regular 40-start-udev-or-load-modules.sh will handle it from here
udevadm control --exit 2>/dev/null
killall udevd 2>/dev/null

# Mark as loaded to prevent double execution
touch /tmp/.rear-overlay-loaded

echo "Overlay loaded successfully."
