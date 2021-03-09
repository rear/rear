# Special cases of kernel module loading.

# XEN PV does not autoload some modules:
test -d /proc/xen && modprobe xenblk

# On POWER architecture the nvram kernel driver may be no longer built into the kernel
# but nowadays it could be also built as a kernel module that needs to be loaded
# cf. https://github.com/rear/rear/issues/2554#issuecomment-764720180
# because normally grub2-install gets called without the '--no-nvram' option
# e.g. see finalize/Linux-ppc64le/620_install_grub2.sh
# which is how grub2-install should be called when the hardware supports nvram.
# Nothing to do when the character device node /dev/nvram exists
# because then the nvram kernel driver is already there:
if ! test -c /dev/nvram ; then
    # Nothing can be done when there is no nvram kernel module.
    # Suppress the possible 'modprobe -n nvram' error message like
    # "modprobe: FATAL: Module nvram not found in directory /lib/modules/..."
    # to avoid a possible "FATAL" false alarm message that would appear
    # on the user's terminal during recovery system startup
    # cf. https://github.com/rear/rear/pull/2537#issuecomment-741825046
    # but when there is a nvram kernel module show possible 'modprobe nvram'
    # (error) messages on the user's terminal during recovery system startup:
    modprobe -n nvram 2>/dev/null && modprobe nvram
fi
