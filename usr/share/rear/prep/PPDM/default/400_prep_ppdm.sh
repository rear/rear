#
# sanity checks and prepare stuff for PPDM
#

[[ "$PPDM_DD_IP" == "" &&
    "$PPDM_STORAGE_UNIT" == "" &&
    "$PPDM_DD_USERNAME" == "" &&
    "$PDM_DD_CONFIG_TYPE" == "" ]] ||
    Error "PPDM variables PPDM_DD_IP PPDM_STORAGE_UNIT PPDM_DD_USERNAME PPDM_DD_CONFIG_TYPE may not be set in configuration, they are only used internally"

COPY_AS_IS+=("${COPY_AS_IS_PPDM[@]}")
COPY_AS_IS_EXCLUDE+=("${COPY_AS_IS_EXCLUDE_PPDM[@]}")
REQUIRED_PROGS+=("${PROGS_PPDM[@]}")

# Use a PPDM-specific LD_LIBRARY_PATH to find PPDM-related libraries, collect all lib or lib64 dirs
LD_LIBRARY_PATH_FOR_BACKUP_TOOL=$(find $_PPDM_INSTALL_DIR -type d -not -path "*tmp*" -name "lib*" -printf ":%p" | cut -c 2-)

if test -d /boot/efi; then
    # PPDM doesn't support vfat for ESP recovery, handle in ReaR
    RESTORE_ESP_FROM_RESCUE_SYSTEM=yes
fi
