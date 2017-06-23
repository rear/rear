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
if ! drbdadm role $resource &>/dev/null ; then
   drbdadm -- --force create-md $resource
fi

EOF

    # Ask if we need to become primary.
    # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    read -p "Type 'yes' if you want DRBD resource $resource to become primary: " 0<&6 1>&7 2>&8
    if [ "$REPLY" = "yes" ] ; then
        cat >> "$LAYOUT_CODE" <<-EOF
        if ! drbdadm role $resource &>/dev/null ; then
           drbdadm up $resource
           drbdadm -- --overwrite-data-of-peer primary $resource
        fi
	EOF
    else
        # Mark things which depend on this drbd resource as "done" (recursively).
        mark_tree_as_done "$disk"
        EXCLUDE_RESTORE=( "${EXCLUDE_RESTORE[@]}" "$disk" )
    fi
}
