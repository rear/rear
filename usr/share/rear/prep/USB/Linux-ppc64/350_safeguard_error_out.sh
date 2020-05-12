
# prep/USB/Linux-<non-i386-architectures>/350_safeguard_error_out.sh
# are safeguard scripts to let "rear mkrescue/mkbackup" error out in case of
# false usage of OUTPUT=USB on non PC-compatible (i386/x86/x86_64) architectures
# because with OUTPUT=USB on those architectures the USB medium cannot be booted
# (for those architectures there are no scripts that install a bootloader)
# so OUTPUT=USB on those architectures does not provide what the user expects
# (cf. the "OUTPUT=USB" section in default.conf what the expected behaviour is)
# see https://github.com/rear/rear/issues/2348
#
# OUTPUT=USB on POWER architecture:
# The actual script is prep/USB/Linux-ppc64/350_safeguard_error_out.sh
# and its symbolic link prep/USB/Linux-ppc64le/350_safeguard_error_out.sh
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
#
# OUTPUT=USB on IBM Z (s390/s390x) architecture:
# The symbolic link prep/USB/Linux-s390/350_safeguard_error_out.sh
# and its link target prep/USB/Linux-ppc64/350_safeguard_error_out.sh
#
# OUTPUT=USB on ARM architecture:
# The symbolic link prep/USB/Linux-arm/350_safeguard_error_out.sh
# and its link target prep/USB/Linux-ppc64/350_safeguard_error_out.sh

Error "OUTPUT=USB not supported on $ARCH (no support to install a bootloader)"

