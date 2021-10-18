# Get available serial devices
function get_serial_console_devices {
    if [ -z $SERIAL_CONSOLE_DEVICES ]; then
        serial_devices=$(ls /dev/ttyS[0-9]* /dev/hvsi[0-9]* | sort)
        echo "$serial_devices"
    else
        $SERIAL_CONSOLE_DEVICES
    fi
}

function cmdline_add_console {
    # Enable serial console, unless explicitly disabled
    if [[ ! "$USE_SERIAL_CONSOLE" =~ ^[yY1] ]]; then
        return
    fi

    # Add serial console to /etc/inittab and kernel cmdline
    # ignore console kernel cmd parameters
    cmdline=
    for param in $KERNEL_CMDLINE; do
        case "$param" in
            (console=*) ;;
            (*) cmdline+=" $param";;
        esac
    done

    # add serial console config to kernel cmd line
    serial_devices=$(get_serial_console_devices)
    for devnode in $serial_devices; do
        speed=$(stty -F $devnode 2>/dev/null | awk '/^speed / { print $2 }')
        if [ "$speed" ]; then
            cmdline="${cmdline}console=${devnode##/dev/},$speed "
        fi
    done

    # add console default if no real serial console device was found
    if [ -z $serial_devices ]; then
        cmdline="${cmdline}console=tty0 "
    fi

    echo "$cmdline"
}
