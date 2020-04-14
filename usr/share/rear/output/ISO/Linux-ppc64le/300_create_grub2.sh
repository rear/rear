# 300_create_grub2.sh
#
# create grub.cfg for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# create grub directory structure
mkdir -p $v $TMP_DIR/ppc
cat >"$TMP_DIR/ppc/bootinfo.txt" <<EOF
<chrp-boot>
<description>Relax-and-Recover</description>
<os-name>Linux</os-name>
<boot-script>boot &device;:,\boot\grub\powerpc.elf</boot-script>
</chrp-boot>
EOF

mkdir -p $v $TMP_DIR/boot/grub
cat >"$TMP_DIR/boot/grub/grub.cfg" <<EOF
set timeout=100

menuentry "Relax-and-Recover" {
	linux   /kernel root=/dev/ram0 $KERNEL_CMDLINE
	initrd  /$REAR_INITRD_FILENAME
}
EOF

grub_name=grub2
$grub_name-mkimage --version >/dev/null
if [ $? -ne 0 ]; then
    grub_name=grub
fi

$grub_name-mkimage -O powerpc-ieee1275 -p '()/boot/grub' -o $TMP_DIR/boot/grub/powerpc.elf linux normal iso9660

# FIXME: Those additional array elements are no ISO files
# so what is that special code meant to do?
ISO_FILES+=( boot=boot ppc=ppc )
