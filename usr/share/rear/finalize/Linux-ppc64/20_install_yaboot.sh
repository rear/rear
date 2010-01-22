# Reinstall yaboot boot loader
LogPrint "Installing PPC PReP Boot partition."

# Find PPC PReP Boot partitions
if test -f /mnt/local/etc/yaboot.conf; then
  part=`awk -F '=' '/^boot=/ {print $2}' /mnt/local/etc/yaboot.conf`

  if [ -n "$part" ]; then
    LogPrint "Boot partion found: $part"
    chroot /mnt/local /bin/bash --login -c "mkofboot -b $part --filesystem raw"
    bootdev=`echo $part | sed -e 's/[0-9]*$//'`
    LogPrint "Boot device is $bootdev."
    bootlist -m normal $bootdev
  else
    bootparts=`sfdisk -l 2>/dev/null | awk '/PPC PReP Boot/ {print $1}'`
    LogPrint "Boot partitions found: $bootparts."
    for part in $bootparts
    do
      LogPrint "Initializing boot partition $part."
      chroot /mnt/local /bin/bash --login -c "mkofboot -b $part --filesystem raw"
    done
    bootdev=`for part in $bootparts
             do
               echo $part | sed -e 's/[0-9]*$//'
             done | sort | uniq`
    LogPrint "Boot device list is $bootdev."
    bootlist -m normal $bootdev
  fi
else
  LogPrint "No bootloader configuration found. Install boot partition manually!"
fi

