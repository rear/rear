#
#  s390 zIPL boot loader and grubby for configuring boot loader`

[ "$ARCH" == "Linux-s390"  ] || return 0

test -d $VAR_DIR/recovery || mkdir -p $VAR_DIR/recovery

local bootdir="$( echo -n /boot/ )"
test -d "$bootdir" || $bootdir='/boot/'

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
PROGS+=( findmnt dasd_cio_free dasdfmt dasdinfo dasdstat dasdview dasdconf.sh fdasd qetharp qethconf qethqoat )
PROGS+=( cmsfscat  cmsfsck  cmsfscp  cmsfslst  cmsfsvol )
PROGS+=( chccwdev chshut chiucvallow chchp tape390_crypt tape390_display )
PROGS+=( lsdasd lsqeth lstape )
PROGS+=( cio_ignore zdump zfcpconf.sh zgetdump ziomon ziomon_mgr ziomon_zfcpdd ziorep_traffic znetconf )
PROGS+=( fcp_cio_free zfcpdbf zic ziomon_fcpconf ziomon_util ziorep_config ziorep_utilization znet_cio_free zramctl )

COPY_AS_IS+=( /etc/zipl.conf /lib/s390-tools )


