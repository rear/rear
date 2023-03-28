
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

# Auto-enable serial console support for the recovery system
# unless the user specified to not have serial console support:
is_false "$USE_SERIAL_CONSOLE" && return 0

# Scan the kernel command line of the currently running original system
# and auto-enable serial console support for the recovery system
# only if there is at least one 'console=...' option:
local kernel_option
for kernel_option in $( cat /proc/cmdline ) ; do
    # Get the kernel option name (part before leftmost "="):
    if test "${kernel_option%%=*}" = "console" ; then
        USE_SERIAL_CONSOLE="yes"
        # Get all 'console=...' kernel command line options
        # copied from the currently running original system
        # via rescue/GNU/Linux/290_kernel_cmdline.sh that runs later:
        COPY_KERNEL_PARAMETERS+=( console )
        break
    fi
done
