# FIXME - FIXME ASAP - BTRFS restore has randomly corrupted files
###################################################################
# Reason is not clear yet - btrfsck returns no errors - tar also seem clean
# but still some files (like grub.conf became data instead of ascii)
# Investigation still required - perhaps btrfs needs some special tuning
# before restoring - ANY HELP IS MORE THEN WELCOME
###################################################################
# by fixing grub.conf we pass the GRUB and boot but then we're stuck at
# systemd (init) with other corrupted config files ;-//

# /mnt/local/etc/grub.conf could be corrupt, but why??
if [ -f $VAR_DIR/recovery/mkbootloader ] ; then
     if ! $(diff /etc/grub.conf /mnt/local/etc/grub.conf >&8) ; then
         cp $v /etc/grub.conf /mnt/local/etc/grub.conf >&8
     fi
fi


# this script must be deleted after BTRFS restore is fixed!!!!!!!!!!!!!
# we will mark BTRFS as experimental in our release notes for 1.12.0
