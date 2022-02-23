#
#  s390 zIPL boot loader and grubby for configuring boot loader`

test -d $VAR_DIR/recovery || mkdir -p $VAR_DIR/recovery

# See the code in prep/GNU/Linux/300_include_grub_tools.sh
# that sets grubdir via
#   local grubdir="$( echo -n /boot/grub* )"
# where 'shopt -s nullglob' results nothing when nothing matches
# but that is not needed here to set a fixed bootdir="/boot"
# cf. https://github.com/rear/rear/issues/1040#issuecomment-1034890880
local bootdir="/boot/"

# cf. https://github.com/rear/rear/issues/2137
# findmnt is used the same as grub-probe to find the device where /boot is mounted
# example
# findmnt -no SOURCE --target /boot
# --> /dev/dasda1
#
# on sles:
#   findmnt returns --> /dev/dasda3[/@/.snapshots/1/snapshot]
#   use 300_include_grub_tools.sh instead of this file (grub2-probe)
if has_binary findmnt ; then
    findmnt -no SOURCE --target $bootdir >$VAR_DIR/recovery/bootdisk || return 0
fi

# Missing programs in the PROGS array are ignored:
# zipl and grubby are  added in conf/Linux-s390x.conf
# cf. https://github.com/rear/rear/pull/2142#issuecomment-499529607
# move most progs to local.conf until deemed needed
PROGS+=( findmnt dasdfmt dasdinfo dasdview fdasd chattr )
PROGS+=( lsdasd lsqeth lstape )
PROGS+=( cio_ignore znetconf chccwdev qethconf )
PROGS+=( getenforce setenforce sestatus setfiles chcon restorecon avcstat getsebool matchpathcon selinuxconlist selinuxdefcon selinuxenabled togglesebool )
PROGS+=( zipl grubby ed vmcp vmur )

COPY_AS_IS+=( /etc/zipl.conf /lib/s390-tools )

