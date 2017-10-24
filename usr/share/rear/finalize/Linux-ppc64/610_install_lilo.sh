# THIS SCRIPT CONTAINS PPC64/PPC64LE SPECIFIC
#################################################################

# skip if lilo conf is not found
test -f $TARGET_FS_ROOT/etc/lilo.conf || return 0

# Reinstall lilo boot loader
LogPrint "Installing PPC PReP Boot partition."

LogPrint "Running LILO ..."
chroot $TARGET_FS_ROOT /sbin/lilo
[ $? -eq 0 ] && NOBOOTLOADER=

test $NOBOOTLOADER && LogPrint "No bootloader configuration found. Install boot partition manually."
