# 240_include_multipath_tools.sh
# Boot Over SAN executables and other goodies

# Run the following only if BOOT_OVER_SAN is true
is_true "$BOOT_OVER_SAN" || return 0

PROGS+=( multipath mpathconf dmsetup kpartx multipathd scsi_id  )
COPY_AS_IS+=( /etc/multipath.conf /etc/multipath/* /lib*/multipath )

# depending to the linux distro and arch, libaio can be located in different dir. (ex: /lib/powerpc64le-linux-gnu)
for libdir in $(ldconfig -p | awk '/libaio.so/ { print $NF }' | xargs -n1 dirname | sort -u); do
    libaio2add="$libaio2add $libdir/libaio*"
done
LIBS+=( $libaio2add )
