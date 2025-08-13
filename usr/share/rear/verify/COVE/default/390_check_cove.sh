#
# Check if the Backup Manager is installed
#

if [ -z "${COVE_INSTALL_DIR}" ]; then
    Error "COVE_INSTALL_DIR cannot be empty. Please define it in local.conf."
fi

for executable in BackupFP ClientTool ProcessController; do
    if [ ! -x "${COVE_INSTALL_DIR}/bin/${executable}" ]; then
        Error "The Backup Manager is either not installed or corrupted."
    fi
done

if [[ "${REAR_DIR_PREFIX}/" == "${COVE_INSTALL_DIR}/"* ]]; then
    Error "ReaR can not be executed from COVE_INSTALL_DIR"
fi

if [[ "$OS_VENDOR" =~ "RedHat" ]] && [ "${OS_VERSION%%.*}" = "6" ] ; then
    if ! grep -qw "vsyscall=emulate" /proc/cmdline; then
        Error "RHEL 6 requires enabling vsyscall=emulate in the kernel boot parameters." \
              "Please reboot the rescue system, press 'e' in GRUB menu, and append 'vsyscall=emulate' in the boot parameters."
    fi
fi
