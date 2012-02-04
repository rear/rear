# Code to create DRBD

# this requires DRBD configuration present!
create_drbd() {
    local drbd disk resource device junk
    read drbd disk resource device junk < <(grep "^drbd $1" $LAYOUT_FILE)

    cat >> $LAYOUT_CODE <<EOF
if [ ! -e /proc/drbd ] ; then
    modprobe drbd
fi

mkdir -p /var/lib/drbd

LogPrint "Creating DRBD resource $resource"
dd if=/dev/zero of=$device bs=1M count=20
sync
drbdadm create-md $resource

EOF

    # ask if we need to become primary
    read 2>&1 -p "Type \"Yes\" if you want DRBD resource $resource to become primary: "
    if [ "$REPLY" = "Yes" ] ; then
        cat >> $LAYOUT_CODE <<EOF
# We assume DRBD on LVM
drbdadm attach $resource
drbdadm -- --overwrite-data-of-peer primary $resource
EOF
    else
        cat >> $LAYOUT_CODE <<EOF
# LVM on DRBD
drbdadm up $resource
EOF

        # mark things which depend on this drbd resource as "done" (recursively)
        mark_tree_as_done "$disk"
        EXCLUDE_RESTORE=( "${EXCLUDE_RESTORE[@]}" "$disk" )
    fi
}
