# find isolinux.bin or abort if it cannot be found

# find isolinux.bin
if [[ ! -s "$ISO_ISOLINUX_BIN" ]]; then
	for file in /usr/{share,lib,libexec}/*/isolinux.bin ; do
		if [[ -s "$file" ]]; then
			ISO_ISOLINUX_BIN="$file"
			break # for loop
		fi
	done

fi
[[ -s "$ISO_ISOLINUX_BIN" ]]
ProgressStopIfError $? "Could not find 'isolinux.bin'. Maybe you have to set ISO_ISOLINUX_BIN [$ISO_ISOLINUX_BIN] or install the syslinux package ?"

# Define the syslinux directory for later usage
SYSLINUX_DIR=$(dirname $ISO_ISOLINUX_BIN)

[[ -s "$SYSLINUX_DIR/mbr.bin" ]]
ProgressStopIfError $? "Could not find 'mbr.bin' in $SYSLINUX_DIR. Maybe syslinux version is too old ?"

