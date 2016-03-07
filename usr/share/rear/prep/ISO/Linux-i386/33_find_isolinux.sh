# find isolinux.bin or abort if it cannot be found

# find isolinux.bin
if [[ ! -s "$ISO_ISOLINUX_BIN" ]]; then
    ISO_ISOLINUX_BIN=$(find_syslinux_file isolinux.bin)
fi

[[ -s "$ISO_ISOLINUX_BIN" ]]
StopIfError "Could not find 'isolinux.bin'. Maybe you have to set ISO_ISOLINUX_BIN [$ISO_ISOLINUX_BIN] or install the syslinux package ?"

# Define the syslinux directory for later usage
SYSLINUX_DIR=$(dirname $ISO_ISOLINUX_BIN)
