# 300_create_isolinux.sh
#
# create yaboot.cfg for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

## other bootloader distro case
if [[ ! -r /etc/yaboot.conf ]] && [[ ! -r /etc/lilo.conf ]] ; then
    return
fi

SUSE_STYLE=

# create yaboot directory structure
mkdir -p $v $TMP_DIR/ppc/chrp
ISO_YABOOT_BIN=$(find_yaboot_file yaboot)

if [[ $ISO_YABOOT_BIN == *"/lib/lilo/pmac"* ]] ; then
   ISO_YABOOT_BIN="/lib/lilo/chrp/yaboot.chrp"
   SUSE_STYLE=1
fi

if [[ "$SUSE_STYLE" ]] ; then
  #SUSE type distos
  cp $v $ISO_YABOOT_BIN $TMP_DIR/yaboot
  # SUSE ppc64 use /yaboot, need to add it to ISO_FILES see #1407
  ISO_FILES=( ${ISO_FILES[@]} yaboot )

cat >"$TMP_DIR/ppc/bootinfo.txt" <<EOF
<chrp-boot>
<description>Relax-and-Recover</description>
<os-name>Linux</os-name>
<boot-script>boot &device;:\yaboot</boot-script>
</chrp-boot>
EOF

else
  #Red Hat type distros
  cp $v $ISO_YABOOT_BIN $TMP_DIR/ppc/chrp

cat >"$TMP_DIR/ppc/bootinfo.txt" <<EOF
<chrp-boot>
<description>Relax-and-Recover</description>
<os-name>Linux</os-name>
<boot-script>boot &device;:\ppc\chrp\yaboot</boot-script>
</chrp-boot>
EOF

fi

mkdir -p $v $TMP_DIR/etc
cat >"$TMP_DIR/etc/yaboot.conf" <<EOF
init-message = "\nRelax-and-Recover boot\n\n"
timeout=100
default=Relax-and-Recover

image=kernel
	label=Relax-and-Recover
	initrd=$REAR_INITRD_FILENAME
	append=" root=/dev/ram0 $KERNEL_CMDLINE"

EOF

# FIXME: Those additional array elements are no ISO files
# so what is that special code meant to do?
ISO_FILES+=( etc=etc ppc=ppc )
