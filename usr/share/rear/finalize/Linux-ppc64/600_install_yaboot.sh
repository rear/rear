# THIS SCRIPT CONTAINS PPC64/PPC64LE SPECIFIC
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

# Reinstall yaboot boot loader
LogPrint "Installing PPC PReP Boot partition."

test -z "$PREP_BOOT_PART" && LogPrint "PReP boot partition not found."

LogPrint "Running mkofboot ..."
chroot $TARGET_FS_ROOT /sbin/mkofboot -b "$PREP_BOOT_PART" --filesystem raw -f
[ $? -eq 0 ] && NOBOOTLOADER=

test $NOBOOTLOADER && LogPrint "No bootloader configuration found. Install boot partition manually."
