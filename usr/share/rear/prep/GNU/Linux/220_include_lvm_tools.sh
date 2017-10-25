# Include LVM tools if LVM exists

test -c /dev/mapper/control -a -x "$(get_path lvm)" || return 0 # silently skip

Log "Device mapper found enabled. Including LVM tools."

PROGS=( "${PROGS[@]}"
lvm
dmsetup
dmeventd
fsadm
)
COPY_AS_IS=( "${COPY_AS_IS[@]}"
/etc/lvm
)
