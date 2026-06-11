# THIS SCRIPT CONTAINS PPC64 SPECIFIC
#################################################################
# The purpose of this script is to check if the "part" variable in /etc/lilo.conf
# is an existing disk partition on the local system. If not replace it with the PReP
# partition path.
#
# This script must be run before 610_intall_lilo.sh and 550_rebuild_initramfs.sh
#################################################################

# skip if lilo conf is not found
test -f $TARGET_FS_ROOT/etc/lilo.conf || return 0

# Find PPC PReP Boot partitions
part=$( awk -F '=' '/^boot/ {print $2}' $TARGET_FS_ROOT/etc/lilo.conf )

# test $part is not null and is an existing partition on the current system.
if ( test -n "$part" ) && ( fdisk -l | grep -q "$part" ) ; then
    LogPrint "Boot partition found in lilo.conf: $part"
    # Run lilo directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
else
    # If the device found in lilo.conf is not valid, find prep partition in
    # disklayout file and use it in lilo.conf.
    LogPrint "Can't find a valid partition from lilo.conf"
    LogPrint "Looking for PPC PReP partition in $DISKLAYOUT_FILE"
    newpart=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $DISKLAYOUT_FILE )
    LogPrint "Updating boot = $newpart in lilo.conf"
    sed -i -e "s|^boot.*|boot = $newpart|" $TARGET_FS_ROOT/etc/lilo.conf
fi
