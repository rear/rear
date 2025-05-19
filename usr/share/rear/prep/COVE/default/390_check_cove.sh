#
# Check if the Backup Manager is installed
#

if [ -z "$COVE_INSTALL_DIR" ]; then
    Error "COVE_INSTALL_DIR cannot be empty. Please define it in local.conf."
fi

for executable in BackupFP ClientTool ProcessController; do
    if [ ! -x "${COVE_INSTALL_DIR}/bin/${executable}" ]; then
        Error "The Backup Manager is either not installed or corrupted."
    fi
done
