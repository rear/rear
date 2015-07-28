# #30_create_grub2.sh
#
# create grub.cfg for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

# create grub directory structure
mkdir -p $v $TMP_DIR/ppc >&2
cat >"$TMP_DIR/ppc/bootinfo.txt" <<EOF
<chrp-boot>
<description>Relax-and-Recover</description>
<os-name>Linux</os-name>
<boot-script>boot &device;:\boot\grub\powerpc.elf</boot-script>
</chrp-boot>
EOF

mkdir -p $v $TMP_DIR/boot/grub >&2
cat >"$TMP_DIR/boot/grub/grub.cfg" <<EOF
set timeout=100

menuentry "Relax-and-Recover" {
	linux   /kernel root=/dev/ram0 $KERNEL_CMDLINE
	initrd  /initrd.cgz
}
EOF

grub_name=grub2
$grub_name-mkimage --version >&8
if [ $? -ne 0 ]; then
    grub_name=grub
fi

$grub_name-mkimage -O powerpc-ieee1275 -p '()/boot/grub' -o $TMP_DIR/boot/grub/powerpc.elf linux normal iso9660

ISO_FILES=( "${ISO_FILES[@]}" boot=boot ppc=ppc )
