# Enable serial console, unless explicitly disabled
if [[ ! "$USE_SERIAL_CONSOLE" =~ ^[yY1] ]]; then
    return
fi

# Add serial console to /etc/inittab and kernel cmdline
cmdline=
for param in $KERNEL_CMDLINE; do
    case "$param" in
        (console=*) ;;
        (*) cmdline="$cmdline$param ";;
    esac
done

for devnode in $(ls /dev/ttyS[0-9]* /dev/hvsi[0-9]* | sort); do
    speed=$(stty -F $devnode 2>&8 | awk '/^speed / { print $2 }')
    if [ "$speed" ]; then
        cmdline="${cmdline}console=${devnode##/dev/},$speed "
    fi
done

# Default to standard console (can be changed in syslinux menu at boot-time)
if [[ " $cmdline" != "$KERNEL_CMDLINE " ]]; then
    KERNEL_CMDLINE="${cmdline}console=tty0"
fi

Log "Modified kernel commandline to: '$KERNEL_CMDLINE'"
