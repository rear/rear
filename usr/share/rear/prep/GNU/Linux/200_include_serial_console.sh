
# If possible auto-enable serial console when not specified:
if [[ -z "$USE_SERIAL_CONSOLE" ]] ; then
    local devnode speed=""
    for devnode in $( get_serial_console_devices ) ; do
        # Enable serial console when there is at least one real serial device:
        if speed=$( get_serial_device_speed $devnode ) ; then
            USE_SERIAL_CONSOLE="yes"
            break
        fi
    done
fi

# Always include getty or agetty as we don't know in advance whether they are needed
# (the user may boot the recovery system with manually specified kernel options
# to get serial console support in his recovery system).
# For serial support we need to include the agetty binary,
# but Debian distro's use getty instead of agetty:
local getty_binary=""
if has_binary getty ; then
    # Debian, Ubuntu,...
    getty_binary="getty"
elif has_binary agetty ; then
    # Fedora, RHEL, SLES,...
    getty_binary="agetty"
else
    # The user must have the programs in REQUIRED_PROGS installed on his system:
    Error "Failed to find 'getty' or 'agetty' for serial console"
fi

REQUIRED_PROGS+=( "$getty_binary" stty )
