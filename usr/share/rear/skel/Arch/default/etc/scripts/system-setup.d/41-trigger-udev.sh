# Trigger module autoloading for Arch Linux
if [ -s /etc/udev/rules.d/00-rear.rules ] && [ -w /sys/kernel/uevent_helper ] ; then
    if [ -e /lib/udev/load-modules.sh ] && type -p udevadm >/dev/null ; then
        # Arch linux needs the MOD_AUTOLOAD variable set to yes
        # and the default rules rely on a special startup property
        export MOD_AUTOLOAD="yes"
        udevadm control --property=STARTUP=1
        udevadm trigger --action=add --type=devices
        udevadm trigger --action=add --type=subsystems

        udevadm settle
        # Unset STARTUP for normal operation
        udevadm control --property=STARTUP=
    fi
fi
