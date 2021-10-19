
# Get available serial devices:
function get_serial_console_devices () {
    # Use plain 'sort' which results /dev/ttyS0 /dev/ttyS1 /dev/ttyS10 ... /dev/ttyS19 /dev/ttyS2 /dev/ttyS20 ...
    # to get at least /dev/ttyS0 and /dev/ttyS1 before the other /dev/ttyS* devices because
    # we cannot use "sort -V" which would result /dev/ttyS0 /dev/ttyS1 ... /dev/ttyS9 /dev/ttyS10 ...
    # because in older Linux distributions 'sort' does not support '-V' e.g. SLES10 with GNU coreutils 5.93
    # (SLES11 with GNU coreutils 8.12 supports 'sort -V') but if 'sort' fails there is no output at all
    # cf. "Maintain backward compatibility" at https://github.com/rear/rear/wiki/Coding-Style
    test "$SERIAL_CONSOLE_DEVICES" && echo $SERIAL_CONSOLE_DEVICES || ls /dev/ttyS[0-9]* /dev/hvsi[0-9]* | sort
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

# Add serial console to /etc/inittab and kernel cmdline:
function cmdline_add_console {
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

    # Add serial console config to kernel cmd line for real serial devices:
    local devnode speed=""
    for devnode in $( get_serial_console_devices ) ; do
        speed=$( get_serial_device_speed $devnode ) && cmdline+=" console=${devnode##/dev/},$speed"
    done

    # Add fallback console if no real serial device was found:
    test "$speed" || cmdline+=" console=tty0"

    # Have a trailing space to be on the safe side
    # so that more kernel cmd parameters could be "just appended" by other scripts:
    echo "$cmdline "
}
