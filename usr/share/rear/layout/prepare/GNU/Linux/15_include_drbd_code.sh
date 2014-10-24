# Code to create DRBD.

# This requires DRBD configuration present!
create_drbd() {
    local drbd disk resource device junk
    read drbd disk resource device junk < <(grep "^drbd $1 " "$LAYOUT_FILE")

    cat >> "$LAYOUT_CODE" <<EOF
if [ ! -e /proc/drbd ] ; then
    modprobe drbd
fi

mkdir -p /var/lib/drbd

LogPrint "Creating DRBD resource $resource"
dd if=/dev/zero of=$device bs=1M count=20
sync
drbdadm create-md $resource

EOF

    # Ask if we need to become primary.
    read 2>&1 -p "Type \"yes\" if you want DRBD resource $resource to become primary: "
    if [ "$REPLY" = "yes" ] ; then
        cat >> "$LAYOUT_CODE" <<-EOF
        drbdadm up $resource
        drbdadm -- --overwrite-data-of-peer primary $resource
	EOF
    else
        cat >> "$LAYOUT_CODE" <<-EOF
        drbdadm attach $resource
	EOF

        # Mark things which depend on this drbd resource as "done" (recursively).
        mark_tree_as_done "$disk"
        EXCLUDE_RESTORE=( "${EXCLUDE_RESTORE[@]}" "$disk" )
    fi
}
