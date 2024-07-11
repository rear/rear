# THIS SCRIPT CONTAINS PPC64 SPECIFIC
#################################################################
# The purpose of this script is to check if the "part" variable in /etc/yaboot.conf
# is an existing disk partition on the local system. If not replace it with the PReP
# partition path.
#
# This script must be run before 600_intall_yaboot.sh and 550_rebuild_initramfs.sh
#################################################################

# skip if yaboot conf is not found
test -f $TARGET_FS_ROOT/etc/yaboot.conf || return 0

# check if yaboot.conf is managed by lilo, if yes, return
if test -f $TARGET_FS_ROOT/etc/lilo.conf; then
    # if the word "initrd-size" is present in yaboot.conf, this mean it should be
    # managed by lilo.
    if grep -qw initrd-size $TARGET_FS_ROOT/etc/yaboot.conf; then
        LogPrint "yaboot.conf found but seems to be managed by lilo."
        return
    fi
fi

# Find PPC PReP Boot partitions
PREP_BOOT_PART=$( awk -F '=' '/^boot/ {print $2}' $TARGET_FS_ROOT/etc/yaboot.conf )

# test $PREP_BOOT_PART is not null and is an existing partition on the current system.
if ( test -n "$PREP_BOOT_PART" ) && ( fdisk -l 2>/dev/null | grep -q "$PREP_BOOT_PART" ) ; then
    LogPrint "Boot partition found in yaboot.conf: $PREP_BOOT_PART"
    # Run mkofboot directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
else
    # If the device found in yaboot.conf is not valid, find prep partition in
    # disklayout file and use it in yaboot.conf.
    LogPrint "Can't find a valid partition in yaboot.conf"
    LogPrint "Looking for PPC PReP partition in $DISKLAYOUT_FILE"
    new_boot_part=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $DISKLAYOUT_FILE )
    LogPrint "Updating boot = $new_boot_part in lilo.conf"
    sed -i -e "s|^boot.*|boot = $new_boot_part|" $TARGET_FS_ROOT/etc/yaboot.conf
    PREP_BOOT_PART="$new_boot_part"
fi
