# THIS SCRIPT CONTAINS PPC64/PPC64LE SPECIFIC
#################################################################

# skip if yaboot conf is not found
test -f $TARGET_FS_ROOT/etc/yaboot.conf || return

# Reinstall yaboot boot loader
LogPrint "Installing PPC PReP Boot partition."

# Find PPC PReP Boot partitions
part=$( awk -F '=' '/^boot/ {print $2}' $TARGET_FS_ROOT/etc/yaboot.conf )

# test $part is not null and is an existing partition on the current system.
if ( test -n $part ) && ( fdisk -l 2>/dev/null | grep -q $part ) ; then
    LogPrint "Boot partion found in yaboot.conf: $part"
    # Run mkofboot directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
else
    # If the device found in lilo.conf is not valid, find prep partition in
    # disklayout file and use it in lilo.conf.
    LogPrint "Can't find a valid partition in yaboot.conf"
    LogPrint "Looking for PPC PReP partition in $DISKLAYOUT_FILE"
    newpart=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $DISKLAYOUT_FILE )
    LogPrint "Updating boot = $newpart in lilo.conf"
    sed -i -e "s|^boot.*|boot = $newpart|" $TARGET_FS_ROOT/etc/yaboot.conf
    part=$newpart
fi

LogPrint "Running mkofboot ..."
chroot $TARGET_FS_ROOT /sbin/mkofboot -b $part --filesystem raw -f
[ $? -eq 0 ] && NOBOOTLOADER=

test $NOBOOTLOADER && LogPrint "No bootloader configuration found. Install boot partition manually."
