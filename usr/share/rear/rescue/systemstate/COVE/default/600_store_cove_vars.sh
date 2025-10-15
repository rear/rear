#
# Store Cove variables for recovery:
# - Real installation directory, to install the Backup Manager in the same place at recovery time
# - Timestamp to find the corresponding Files and folders backup session
#

local cove_firmware="BIOS"
if is_true "$USING_UEFI_BOOTLOADER" ; then
    cove_firmware="EFI"
fi

cat <<EOF >>"$ROOTFS_DIR/etc/rear/rescue.conf"

# from rescue/COVE/default/600_store_cove_vars.sh
COVE_REAL_INSTALL_DIR="$(readlink -f "${COVE_INSTALL_DIR}")"
COVE_TIMESTAMP="${COVE_TIMESTAMP}"
COVE_KERNEL_VERSION="${KERNEL_VERSION}"
COVE_FIRMWARE="${cove_firmware}"
EOF
