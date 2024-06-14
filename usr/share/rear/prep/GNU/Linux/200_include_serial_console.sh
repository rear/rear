
# This script prep/GNU/Linux/200_include_serial_console.sh
# is the first ...console... script that is run for "rear mkrescue/mkbackup".
#
# When USE_SERIAL_CONSOLE is empty then this script decides
# if USE_SERIAL_CONSOLE is kept empty
# or (provided there is sufficient reason)
# it sets USE_SERIAL_CONSOLE to 'no' or 'yes'.
# It sets USE_SERIAL_CONSOLE to 'no'
# when serial consoles cannot work in the recovery system.
# It sets USE_SERIAL_CONSOLE to 'yes'
# when a serial console will be set up for the recovery system kernel.
# Only when a serial console will be actually set up for the recovery system kernel,
# then it makes sense to also set up a serial console for the recovery system bootloader.
# So serial console setup for the recovery system bootloader is only done if USE_SERIAL_CONSOLE="yes"
# because an empty USE_SERIAL_CONSOLE must not result serial console setup for the recovery system bootloader
# (without actual serial console setup for the recovery system kernel).

# Always try to include getty or agetty as we do not know in advance whether they are needed
# (the user may boot the recovery system with manually specified kernel options
# to get serial console support in his recovery system).
# For serial console support we need to include 'getty' or 'agetty'.
# Debian distributions (in particular Ubuntu) use 'getty'.
# Fedora, RHEL, SLES,... use 'agetty'.
if has_binary getty ; then
    PROGS+=( getty )
elif has_binary agetty ; then
    PROGS+=( agetty )
else
    is_true "$USE_SERIAL_CONSOLE" && Error "Failed to find 'getty' or 'agetty' (USE_SERIAL_CONSOLE is 'true')"
    LogPrintError "No serial console support (failed to find 'getty' or 'agetty')"
    USE_SERIAL_CONSOLE="no"
fi

# Also try to include 'stty' which is (currently) only needed for serial console support
# in skel/default/etc/scripts/system-setup.d/45-serial-console.sh
# and lib/serial-functions.sh
if has_binary stty ; then
    PROGS+=( stty )
else
    is_true "$USE_SERIAL_CONSOLE" && Error "Failed to find 'stty' (USE_SERIAL_CONSOLE is 'true')"
    LogPrintError "No serial console support (failed to find 'stty')"
    USE_SERIAL_CONSOLE="no"
fi

# Auto-enable serial console support for the recovery system
# provided console support is not impossible because there is no getty or agetty and stty
# and unless the user specified to not have serial console support:
is_false "$USE_SERIAL_CONSOLE" && return 0

# When the user has specified SERIAL_CONSOLE_DEVICES_KERNEL use only that,
# otherwise use SERIAL_CONSOLE_DEVICES if the user has specified it:
local serial_console_devices=""
test "$SERIAL_CONSOLE_DEVICES" && serial_console_devices="$SERIAL_CONSOLE_DEVICES"
test "$SERIAL_CONSOLE_DEVICES_KERNEL" && serial_console_devices="$SERIAL_CONSOLE_DEVICES_KERNEL"
if test "$serial_console_devices" ; then
    local serial_console speed="" cmdline_add_console=""
    for serial_console in $serial_console_devices ; do
        # serial_console can be a character device node like "/dev/ttyS0" or "/dev/lp0" or "/dev/ttyUSB0"
        # cf. https://www.kernel.org/doc/html/latest/admin-guide/serial-console.html
        # or serial_console can be a 'console=...' kernel cmd parameter like "console=ttyS1,9600"
        if test -c "$serial_console" ; then
            if speed=$( get_serial_device_speed $serial_console ) ; then
                cmdline_add_console+=" console=${serial_console##/dev/},$speed"
            else
                cmdline_add_console+=" console=${serial_console##/dev/}"
            fi
        else
            # When serial_console is not a character device
            # it should be a 'console=...' kernel cmd parameter
            # that is used as specified ("final power to the user"):
            cmdline_add_console+=" $serial_console"
        fi
    done
    if test "$cmdline_add_console" ; then
        KERNEL_CMDLINE+="$cmdline_add_console"
        DebugPrint "Appended '$cmdline_add_console' to KERNEL_CMDLINE"
        USE_SERIAL_CONSOLE="yes"
        # No further automatisms when a 'console=...' kernel cmd parameter was set
        # via SERIAL_CONSOLE_DEVICES_KERNEL or SERIAL_CONSOLE_DEVICES:
        return
    fi
    LogPrintError "SERIAL_CONSOLE_DEVICES_KERNEL or SERIAL_CONSOLE_DEVICES specified but none is a character device"
fi

# Auto-enable serial console support for the recovery system kernel:
# The below auto-enable serial console support for the recovery system kernel
# does not auto-enable serial console support for the recovery system bootloader.
# Currently auto-enable serial console support for the recovery system bootloader
# happens for the first real serial device from get_serial_console_devices()
# in lib/bootloader-functions.sh in make_syslinux_config() and create_grub2_cfg() 
# and in output/USB/Linux-i386/300_create_extlinux.sh
# The auto-enable serial console support for the recovery system bootloader should be
# auto-aligned with the auto-enable serial console support for the recovery system kernel.
# Things are auto-aligned when the first 'console=...' device in /proc/cmdline
# is also the first real serial device from get_serial_console_devices().
# When current auto-alignment does not result what the user needs, what is needed can be specified
# via SERIAL_CONSOLE_DEVICES_KERNEL and SERIAL_CONSOLE_DEVICE_SYSLINUX or SERIAL_CONSOLE_DEVICE_GRUB.

# Scan the kernel command line of the currently running original system
# and auto-enable serial console for the recovery system kernel
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
        return
    fi
done
DebugPrint "No 'console=...' setting for recovery system kernel (none in /proc/cmdline)"
