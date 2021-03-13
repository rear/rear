# Include LVM tools if LVM exists

test -c /dev/mapper/control -a -x "$(get_path lvm)" || return 0 # silently skip

Log "Device mapper found enabled. Including LVM tools."

PROGS+=( lvm dmsetup dmeventd fsadm )

COPY_AS_IS+=( /etc/lvm )

if lvs --noheadings -o thin_count | grep -q -v "^\s*$" ; then
    # There are Thin Pools on the system, include required binaries
    PROGS+=( thin_check )
fi

if lvs --noheadings -o modules | grep -q -v "^\s*$" ; then
    # There are non-linear LVs on the system, include required libraries
    LIBS+=( /lib64/*lvm2* )
fi

# vim: set et ts=4 sw=4:
