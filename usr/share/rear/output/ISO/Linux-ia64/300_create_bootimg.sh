# 300_create_bootimg.sh
#
# create elilo.conf for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# finding elilo.efi is now done in the prep stage, not here.
# therefore ELILO_BIN for sure contains the full path to elilo.efi

mkdir $v -p $TMP_DIR/mnt/boot

cp -L $v "$ELILO_BIN" $TMP_DIR/mnt/boot || Error "Failed to copy elilo.efi '$ELILO_BIN'"

cp $v $TMP_DIR/$REAR_INITRD_FILENAME $TMP_DIR/mnt/boot || Error "Failed to copy initrd '$REAR_INITRD_FILENAME'"

# KERNEL_FILE is defined in prep/GNU/Linux/400_guess_kernel.sh
cp $v "$KERNEL_FILE" $TMP_DIR/mnt/boot/kernel || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"

echo "$VERSION_INFO" >$TMP_DIR/mnt/boot/message

cat >"$TMP_DIR/mnt/boot/elilo.conf" <<EOF
prompt
timeout=50

image=kernel
	label=rear
	initrd=$REAR_INITRD_FILENAME
	read-only
	append="ramdisk=512000 $CONSOLE  rhgb selinux=0"
EOF
