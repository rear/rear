
# With OUTPUT=USB on POWER architecture the USB medium cannot be booted
# see https://github.com/rear/rear/issues/2348
#
# Therefore "rear mkrescue/mkbackup" errors out here because
# OUTPUT=USB on POWER architecture does not provide what the user expects.
#
# A workaround to get a bootable USB device on Power BareMetal is
# to make an ISO by using OUTPUT=ISO and copy the ISO on a USB device with
#   dd if=<path_to_rear.iso> of=/dev/<USB_block_device> bs=1M
# cf. https://github.com/rear/rear/issues/2243#issuecomment-537354570
# This works only to boot on Power BareMetal where no PreP partition is needed
# when the Power BareMetal system is using petitboot as system bootloader, cf.
# https://github.com/open-power/petitboot
# In a nuteshell petitboot is a micro-Linux in firmware which loads and
# scans disks and network to find GRUB configurations and aggregate them
# into a single menu (for disk, SAN, network, dvd, usb).
# So, in that case, a PreP partition is not needed, cf.
# https://github.com/rear/rear/issues/2243#issuecomment-605506628

Error "OUTPUT=USB not supported on $ARCH (no support to boot the USB medium)"
