#
# Check if vsyscall=emulate is enabled on RHEL and CentOS 6
#

if [ "${OS_VERSION%%.*}" = "6" ] && ! grep -qw "vsyscall=emulate" /proc/cmdline; then
    Error "RHEL and CentOS 6 systems require enabling vsyscall=emulate in the kernel boot parameters." \
          "Please reboot the rescue system, press 'e' in the GRUB menu, and append 'vsyscall=emulate' to the boot parameters."
fi
