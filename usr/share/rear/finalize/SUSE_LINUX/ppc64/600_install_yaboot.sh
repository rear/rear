# Reinstall yaboot boot loader
LogPrint "Installing PPC PReP Boot partition."

# Find PPC PReP Boot partitions
if test -f $TARGET_FS_ROOT/etc/yaboot.conf ; then
    part=$( awk -F '=' '/^boot=/ {print $2}' $TARGET_FS_ROOT/etc/yaboot.conf )
fi

if test "$part" ; then
    LogPrint "Boot partion found: $part"
    # Run lilo directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
    chroot $TARGET_FS_ROOT /sbin/lilo
    bootdev=$( echo $part | sed -e 's/[0-9]*$//' )
    LogPrint "Boot device is $bootdev."
    NOBOOTLOADER=
else
    # Allow Yaboot bootloader to be recreated even if there is no yaboot.conf
    # (SLES11 ppc64 with /boot in LVM does not have /etc/yaboot.conf).
    LogPrint "Scanning disks for PPC PReP Boot partition..."
    bootparts=$( sfdisk -l 2>&8 | awk '/PPC PReP Boot/ {print $1}' )
    LogPrint "Boot partitions found: $bootparts."
    for part in $bootparts ; do
        # FIXME: This for loop looks wrong because it runs plain '/sbin/lilo' several times
        # (one time for each found boot partition) without a partition specific setting or argument
        # cf. commit 3a7e5bfca57be59a82779af59c2d8d42c6b9b21f
        # Perhaps '/sbin/lilo' has special automated magic built-in but then there should be
        # a comment that explains _why_ it works, cf. https://github.com/rear/rear/wiki/Coding-Style
        LogPrint "Initializing boot partition $part."
        # Run lilo directly in chroot without a login shell in between, see https://github.com/rear/rear/issues/862
        chroot $TARGET_FS_ROOT /sbin/lilo
    done
    bootdev=$( for part in $bootparts ; do echo $part | sed -e 's/[0-9]*$//' ; done | sort | uniq )
    LogPrint "Boot device list is $bootdev."
    NOBOOTLOADER=
fi

test $NOBOOTLOADER && LogPrint "No bootloader configuration found. Install boot partition manually."

