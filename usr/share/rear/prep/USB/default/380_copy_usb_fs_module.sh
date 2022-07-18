
# To be on the safe side when on the USB device a filesystem is used that is not also normally used on this system
# (so the normal automatisms in ReaR may not include a kernel module for the USB filesystem in the recovery system)
# we append a USB filesystem kernel module to the MODULES and MODULES_LOAD arrays if such a kernel module exists.
# Modules in MODULES_LOAD are written to /etc/modules in the recovery system via build/GNU/Linux/400_copy_modules.sh and
# moduels in /etc/modules get loaded during recovery system startup via .../system-setup.d/40-start-udev-or-load-modules.sh

local usb_fs
# TODO: When 'lsblk' is not too old (it must support the needed options like '-o FSTYPE')
# then "lsblk -no FSTYPE $USB_DEVICE" could show the USB filesystem directly
# in its last output line also when it is called with a direct kernel parent device:
# For example my <jsmeix@suse.de> encrypted root filesystem on my openSUSE Leap 15.2 laptop is 'ext4':
#   # lsblk -ipo NAME,KNAME,PKNAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/sda3
#   NAME                                                    KNAME     PKNAME    TYPE  FSTYPE       SIZE MOUNTPOINT
#   /dev/sda3                                               /dev/sda3 /dev/sda  part  crypto_LUKS  200G 
#   `-/dev/mapper/cr_ata-TOSHIBA_MQ01ABF050_Y2PLP02CT-part3 /dev/dm-0 /dev/sda3 crypt ext4         200G /
#   # lsblk -no FSTYPE /dev/dm-0
#   ext4
#   # lsblk -no FSTYPE /dev/mapper/cr_ata-TOSHIBA_MQ01ABF050_Y2PLP02CT-part3
#   ext4
#   # lsblk -no FSTYPE /dev/sda3
#   crypto_LUKS
#   ext4
# It also works when the filesystem is not mounted, for example:
#   # lsblk -ipo NAME,KNAME,PKNAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/sda6
#   NAME      KNAME     PKNAME   TYPE FSTYPE SIZE MOUNTPOINT
#   /dev/sda6 /dev/sda6 /dev/sda part ext2     8G 
#   # lsblk -no FSTYPE /dev/sda6
#   ext2
# It works even for encrypted filesystems that are not mounted
# provided they have been opened and unencrypted with 'cryptsetup luksOpen'
# because nothing what there is inside an encrypted volume could make any sense
# for any program or tool that scans for information inside an encrypted volume
# like what filesystem is used inside an encrypted volume:
#   # lsblk -ipo NAME,KNAME,PKNAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/sda7
#   NAME                    KNAME     PKNAME    TYPE  FSTYPE       SIZE MOUNTPOINT
#   /dev/sda7               /dev/sda7 /dev/sda  part  crypto_LUKS    1G
#   # lsblk -no FSTYPE /dev/sda8
#   crypto_LUKS
#   # cryptsetup luksOpen /dev/sda7 luks1test
#   Enter passphrase for /dev/sda7: ...
#   # lsblk -ipo NAME,KNAME,PKNAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/sda7
#   NAME                    KNAME     PKNAME    TYPE  FSTYPE       SIZE MOUNTPOINT
#   /dev/sda7               /dev/sda7 /dev/sda  part  crypto_LUKS    1G
#   `-/dev/mapper/luks1test /dev/dm-2 /dev/sda7 crypt ext2        1022M
#   # lsblk -no FSTYPE /dev/dm-2
#   ext2
#   # lsblk -no FSTYPE /dev/mapper/luks1test
#   ext2
#   # lsblk -no FSTYPE /dev/sda7
#   crypto_LUKS
#   ext2
# Encryption of the USB filesystem could be a needed feature in the future
# in particular because usually the USB filesystem contains the backup
# and a small USB stick might get lost or accidentally left at a public place.
# For backward compatibility prefer our established 'fsck -N' method at least for now:
usb_fs=$( fsck -N $USB_DEVICE | tail -n 1 | awk '{print $1}' | cut -d. -f2 )
# Try 'lsblk' if the 'fsck -N' method did not result a single non empty and non blank word word,
# cf. "Beware of the emptiness" at https://github.com/rear/rear/wiki/Coding-Style
test $usb_fs || usb_fs=$( lsblk -no FSTYPE $USB_DEVICE | tail -n 1 )
# Use the default USB filesystem ext3 as fallback:
test $usb_fs || usb_fs="ext3"

# Discard normal modinfo stdout (modinfo is used only to test if such a kernel module exists) but
# have modinfo stderr like "modinfo: ERROR: Module ext3 not found" in the log to explain things in debug modes.
# It is crucial to append to /dev/$DEBUG_OUTPUT_DEV when $DEBUG_OUTPUT_DEV is not 'null'.
# In debug modes $DEBUG_OUTPUT_DEV is 'stderr' which is redirected to the log file (see usr/sbin/rear)
# so 2>>/dev/stderr will append to the existing log file (without truncating it to zero size before):
if modinfo "$usb_fs" 1>/dev/null 2>>/dev/$DEBUG_OUTPUT_DEV ; then
    # By default all modules get included in the recovery system via MODULES=( 'all_modules' ) in default.conf:
    IsInArray "all_modules" "${MODULES[@]}" || IsInArray "$usb_fs" "${MODULES[@]}" || MODULES+=( "$usb_fs" )
    IsInArray "$usb_fs" "${MODULES_LOAD[@]}" || MODULES_LOAD+=( "$usb_fs" )
    Log "Having USB Device $USB_DEVICE filesystem $usb_fs kernel module in MODULES and MODULES_LOAD"
else
    # No need to alert the user when there is no kernel module for the USB filesystem
    # because during "rear mkrescue/mkbackup" the USB filesystem is used to store things
    # so it works with the kernel and its modules in the currently running system
    # and this kernel and all its modules get included in the recovery system by default
    # so we can assume that things will also work in the recovery system by default:
    Log "USB Device $USB_DEVICE filesystem $usb_fs is no kernel module (not found by 'modinfo $usb_fs')"
fi
