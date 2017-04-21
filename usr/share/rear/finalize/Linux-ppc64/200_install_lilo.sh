# THIS SCRIPT CONTAINS PPC64/PPC64LE SPECIFIC
#################################################################

# skip if lilo conf is not found
test -f $TARGET_FS_ROOT/etc/lilo.conf || return

# Reinstall lilo boot loader
LogPrint "Installing PPC PReP Boot partition."

# Find PPC PReP Boot partitions
part=$( awk -F '=' '/^boot=/ {print $2}' $TARGET_FS_ROOT/etc/lilo.conf )

if test "$part" && [ -f $part ]; then
    LogPrint "Boot partion found in lilo.conf: $part"
    # Run lilo directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
else
    # If the device found in lilo.conf is not valid, find prep partition in
    # disklayout file and use it in lilo.conf.
    LogPrint "Can't find a valid partition from lilo.conf"
    LogPrint "Looking for PPC PReP partition in $DISKLAYOUT_FILE"
    newpart=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $DISKLAYOUT_FILE )
    LogPrint "Using boot = $newpart in lilo.conf"
    sed -i -e "s!^boot!boot = $newpart!" $TARGET_FS_ROOT/etc/lilo.conf
fi

LogPrint "Running LILO ..."
chroot $TARGET_FS_ROOT /sbin/lilo
[ $? -eq 0 ] && NOBOOTLOADER=
test $NOBOOTLOADER && LogPrint "No bootloader configuration found. Install boot partition manually."
