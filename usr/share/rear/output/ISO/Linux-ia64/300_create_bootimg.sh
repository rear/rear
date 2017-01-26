# 300_create_bootimg.sh
#
# create elilo.conf for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# finding elilo.efi is now done in the prep stage, not here.
# therefore ELILO_BIN for sure contains the full path to elilo.efi

mkdir $v -p $TMP_DIR/mnt/boot >&2
cp -L $v "$ELILO_BIN" $TMP_DIR/mnt/boot >&2
StopIfError "Could not find $ELILO_BIN"

cp $v $TMP_DIR/$REAR_INITRD_FILENAME $TMP_DIR/mnt/boot

#VMLINUX_KERNEL=`find / -xdev -name "vmlinu*-${KERNEL_VERSION}"`
#cp "${VMLINUX_KERNEL}" $TMP_DIR/mnt/boot/kernel

# KERNEL_FILE is defined in pack/Linux-ia64/300_copy_kernel.sh script
cp $v "${KERNEL_FILE}" $TMP_DIR/mnt/boot/kernel >&2
StopIfError "Could not find ${KERNEL_FILE}"

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

ISO_FILES=( "${ISO_FILES[@]}" )
