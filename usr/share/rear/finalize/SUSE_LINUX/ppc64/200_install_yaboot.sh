# Reinstall yaboot boot loader
LogPrint "Installing PPC PReP Boot partition."

# Find PPC PReP Boot partitions
if test -f $TARGET_FS_ROOT/etc/yaboot.conf; then
    part=$( awk -F '=' '/^boot=/ {print $2}' $TARGET_FS_ROOT/etc/yaboot.conf )
fi

if [ -n "$part" ]; then
    LogPrint "Boot partion found: $part"
    chroot $TARGET_FS_ROOT /bin/bash --login -c "/sbin/lilo"
    bootdev=`echo $part | sed -e 's/[0-9]*$//'`
    LogPrint "Boot device is $bootdev."
    NOBOOTLOADER=
else
    # Allow Yaboot bootloader to be recreated even if there is no yaboot.conf
    # (SLES11 ppc64 with /boot in LVM does not have /etc/yaboot.conf).
    LogPrint "Scanning disks for PPC PReP Boot partition..."
    bootparts=`sfdisk -l 2>&8 | awk '/PPC PReP Boot/ {print $1}'`
    LogPrint "Boot partitions found: $bootparts."
    for part in $bootparts
    do
      LogPrint "Initializing boot partition $part."
      chroot $TARGET_FS_ROOT /bin/bash --login -c "/sbin/lilo"
    done
    bootdev=`for part in $bootparts
             do
               echo $part | sed -e 's/[0-9]*$//'
             done | sort | uniq`
    LogPrint "Boot device list is $bootdev."
    NOBOOTLOADER=
fi

if [[ -n $NOBOOTLOADER ]]; then
  LogPrint "No bootloader configuration found. Install boot partition manually!"
fi
