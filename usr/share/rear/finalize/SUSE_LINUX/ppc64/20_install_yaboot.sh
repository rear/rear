# Reinstall yaboot boot loader
LogPrint "Installing PPC PReP Boot partition."

# Find PPC PReP Boot partitions
if test -f $TARGET_FS_ROOT/etc/yaboot.conf; then
  part=$( awk -F '=' '/^boot=/ {print $2}' $TARGET_FS_ROOT/etc/yaboot.conf )

  if [ -n "$part" ]; then
    LogPrint "Boot partion found: $part"
    chroot $TARGET_FS_ROOT /bin/bash --login -c "/sbin/lilo"
    bootdev=`echo $part | sed -e 's/[0-9]*$//'`
    LogPrint "Boot device is $bootdev."
    NOBOOTLOADER=
  else
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
else
  LogPrint "No bootloader configuration found. Install boot partition manually!"
fi

