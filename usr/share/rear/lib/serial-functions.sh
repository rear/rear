
# Get available serial devices:
function get_serial_console_devices () {
    # Via SERIAL_CONSOLE_DEVICES the user specifies which ones to use (and no others):
    if test "$SERIAL_CONSOLE_DEVICES" ; then
        echo $SERIAL_CONSOLE_DEVICES
        return 0
    fi
    # Scan the kernel command line of the currently running original system
    # for 'console=<device>[,<options>]' settings e.g. 'console=ttyS1,9600n8 ... console=ttyS3 ... console=tty0'
    # and extract the specified serial device nodes e.g. ttyS1 -> /dev/ttyS1 ... ttyS3 -> /dev/ttyS3
    local kernel_option console_option_value console_option_device
    for kernel_option in $( cat /proc/cmdline ) ; do
        # Continue with next kernel option when the option name (part before leftmost "=") is not 'console':
        test "${kernel_option%%=*}" = "console" || continue
        # Get the console option value (part after leftmost "=") e.g. 'ttyS1,9600n8' 'ttyS3' 'tty0'
        console_option_value="${kernel_option%%=*}"
        # Get the console option device (part up to first optional comma separator) e.g. 'ttyS1' 'ttyS3' 'tty0'
        console_option_device="${console_option_value%%,*}"
        # Continue with next kernel option when the current console option device is no serial device.
        # The special /dev/hvsi* devices should exist only on systems that have the HVSI driver loaded
        # (a console driver for IBM's p5 servers) cf. https://lwn.net/Articles/98442/
        [[ $console_option_device == ttyS* ]] || [[ $console_option_device == hvsi* ]] || continue
        # Test that the matching serial device node e.g. ttyS1 -> /dev/ttyS1 and ttyS3 -> /dev/ttyS3' exists
        # to avoid that this automated serial console setup may not work in the ReaR recovery system
        # when serial device nodes get specified for the recovery system that do not exist
        # in the currently running original system because the default assumption is
        # that the replacement system has same hardware as the original system,
        # cf. https://github.com/rear/rear/pull/2749#issuecomment-1196650631
        # (if needed the user can specify what he wants via SERIAL_CONSOLE_DEVICES, see above).
        # Intentionally /dev/$console_option_device is unquoted to let the test also fail
        # when $console_option_device is not a single non-empty word (then something is wrong):
        if ! test -c /dev/$console_option_device ; then
            LogPrintError "Found 'console=$console_option_device' in /proc/cmdline but /dev/$console_option_device is no character device"
            continue
        fi
        echo /dev/$console_option_device
    done
}

# Get the serial device speed for those device nodes that belong to actual serial devices.
# When get_serial_device_speed results non-zero exit code the device node does not belong to a real serial device.
function get_serial_device_speed () {
    local devnode=$1
    test -c $devnode || BugError "get_serial_device_speed() called for '$devnode' which is no character device"
    # Run it in a subshell so that 'set -o pipefail' does not affect the current shell and
    # it can run in a subshell because the caller of this function only needs its stdout
    # cf. the function get_root_disk_UUID in lib/bootloader-functions.sh
    # so when stty fails the get_serial_device_speed return code is the stty exit code and not the awk exit code
    # therefore one can call get_serial_device_speed with error checking for example like
    # speed=$( get_serial_device_speed $serial_device ) && COMMAND_WITH_speed || COMMAND_WITHOUT_speed
    # because the return code of variable=$( PIPE ) is the return code of the pipe,
    # cf. how get_serial_device_speed is called in cmdline_add_console below.
    # Suppress stty stderr output because for most /dev/ttyS* device nodes the result is
    #   stty: /dev/ttyS...: Input/output error
    # when the device node does not belong to an actual serial device (i.e. to real serial hardware)
    # so get_serial_device_speed is also used to get those device nodes that belong to real serial devices:
    ( set -o pipefail ; stty -F $devnode 2>/dev/null | awk '/^speed / { print $2 }' )
}

# Add serial console to kernel cmdline:
function cmdline_add_console {

    BugError "function cmdline_add_console is obsoleted"

    # Nothing to do when using serial console is not wanted:
    is_true "$USE_SERIAL_CONSOLE" || return 0

    # Strip existing 'console=...' kernel cmd parameters:
    local param cmdline=""
    for param in $KERNEL_CMDLINE ; do
        case "$param" in
            (console=*) ;;
            (*) cmdline+=" $param";;
        esac
    done

    # Add serial console config to kernel cmd line:
    local devnode speed=""
    if test "$SERIAL_CONSOLE_DEVICES_KERNEL" ; then
        # When the user has specified SERIAL_CONSOLE_DEVICES_KERNEL use only that (no automatisms):
        for devnode in $SERIAL_CONSOLE_DEVICES_KERNEL ; do
            # devnode can be a character device node like "/dev/ttyS0" or "/dev/lp0" or "/dev/ttyUSB0"
            # cf. https://www.kernel.org/doc/html/latest/admin-guide/serial-console.html
            # or devnode can be a 'console=...' kernel cmd parameter like "console=ttyS1,9600"
            if test -c "$devnode" ; then
                if speed=$( get_serial_device_speed $devnode ) ; then
                    cmdline+=" console=${devnode##/dev/},$speed"
                else
                    cmdline+=" console=${devnode##/dev/}"
                fi
            else
                # When devnode is a 'console=...' kernel cmd parameter use it as specified:
                cmdline+=" $devnode"
            fi
        done
    else
        local real_consoles=""
        for devnode in $( get_serial_console_devices ) ; do
            # Only add for those device nodes that belong to actual serial devices:
            speed=$( get_serial_device_speed $devnode ) && real_consoles+=" console=${devnode##/dev/},$speed"
        done
        cmdline+=" $real_consoles"

        # Add fallback console if no real serial device was found:
        test "$real_consoles" || cmdline+=" console=tty0"
    fi

    # Have a trailing space to be on the safe side
    # so that more kernel cmd parameters could be "just appended" by other scripts:
    echo "$cmdline "
}
