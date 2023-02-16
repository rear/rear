# Find isolinux.bin or abort if it cannot be found

# Try to find isolinux.bin (in particular when ISO_ISOLINUX_BIN is empty by default):
test -s "$ISO_ISOLINUX_BIN" || ISO_ISOLINUX_BIN=$( find_syslinux_file isolinux.bin )

# See https://github.com/rear/rear/issues/2921
test -s "$ISO_ISOLINUX_BIN" || Error "Could not find 'isolinux.bin' (ISO_ISOLINUX_BIN='$ISO_ISOLINUX_BIN')"

# Define the syslinux directory for later usage:
SYSLINUX_DIR=$(dirname $ISO_ISOLINUX_BIN)
