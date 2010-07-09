# #09_discover_usb.sh
#
# discover the USB device node
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

# Discover the USB device
if test -z "$USB_DEVNODE" ; then
    USB_DISK=`dmesg | grep 'Attached scsi removable disk sd.' | tail -1 | cut -d' ' -f 7`
    USB_DEVNODE=/dev/$USB_DISK
    LogPrint "Detected USB device node as $USB_DEVNODE"
fi

# If USB_PARTITION is set then mount that partition number.
# Otherwise assume partition 1.

if test -z "$USB_PARTITION" ; then
    USB_PARTITION=1
fi
# Booting syslinux from large VFAT partitions is a problem.  So we
# use USB_PARTITION for the boot partition, and USBFS_PARTITION
# for the partition we are backing up to.  For small USB devices
# they can be the same.
if test -z "$USBFS_PARTITION" ; then
    USBFS_PARTITION=1
fi

# Finally set the USB device of the actual partition we are mounting.

if test -z "$USB_DEVICE" ; then
    USB_DEVICE=${USB_DEVNODE}${USB_PARTITION}
fi
if test -z "$USBFS_DEVICE" ; then
    USBFS_DEVICE=${USB_DEVNODE}${USBFS_PARTITION}
fi
