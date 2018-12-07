# For serial support we need to include the agetty binary, but Debian distro's
# use getty instead of agetty.

# Enable serial console if possible, when not specified
if [[ -z "$USE_SERIAL_CONSOLE" ]]; then
    for devnode in $(ls /dev/ttyS[0-9]* | sort); do
        if stty -F $devnode >/dev/null 2>&1; then
            USE_SERIAL_CONSOLE=y
        fi
    done
fi

# Always include getty or agetty as we don't know in advance whether they are needed
# (the user may boot the recovery system with manually specified kernel options
# to get serial console support in his recovery system):
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

REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" "$getty_binary" stty )
