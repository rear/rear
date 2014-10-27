# Code to recreate an LVM configuration.
# The input to the code creation functions is a file descriptor to one line
# of the layout description.

if ! has_binary lvm; then
    return
fi

# Test for features in lvm.
# Versions higher than 2.02.73 need --norestorefile if no UUID/restorefile.
FEATURE_LVM_RESTOREFILE=

lvm_version=$(get_version lvm version)

[ "$lvm_version" ]
BugIfError "Function get_version could not detect lvm version."

# RHEL 6.0 contains lvm with knowledge of --norestorefile (issue #462)
if version_newer "$lvm_version" 2.02.71 ; then
    FEATURE_LVM_RESTOREFILE="y"
fi

# Create a new PV.
create_lvmdev() {
    local lvmdev vgrp device uuid junk
    read lvmdev vgrp device uuid junk < <(grep "^lvmdev.*${1#pv:} " "$LAYOUT_FILE")

    (
    echo "LogPrint \"Creating LVM PV $device\""

    ### Work around automatic volume group activation leading to active disks
    echo "lvm vgchange -a n ${vgrp#/dev/} || true"

    local uuidopt=""
    local restorefileopt=""

    if [ -z "$MIGRATION_MODE" ] && [ -e "$VAR_DIR/layout/lvm/${vgrp#/dev/}.cfg" ] ; then
        # we have a restore file
        restorefileopt=" --restorefile $VAR_DIR/layout/lvm/${vgrp#/dev/}.cfg"
    else
        if [ -n "$FEATURE_LVM_RESTOREFILE" ] ; then
            restorefileopt=" --norestorefile"
        fi
    fi

    if [ -n "$uuid" ] ; then
        uuidopt=" --uuid \"$uuid\""
    fi
    echo "lvm pvcreate -ff --yes -v$uuidopt$restorefileopt $device >&2"
    ) >> "$LAYOUT_CODE"
}

# Create a new VG.
create_lvmgrp() {
    if [ -z "$MIGRATION_MODE" ] ; then
        restore_lvmgrp "$1"
        return
    fi

    local lvmgrp vgrp extentsize junk
    read lvmgrp vgrp extentsize junk < <(grep "^lvmgrp $1 " "$LAYOUT_FILE")

    local -a devices=($(grep "^lvmdev $vgrp " "$LAYOUT_FILE" | cut -d " " -f 3))

cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Creating LVM VG ${vgrp#/dev/}"
if [ -e "$vgrp" ] ; then
    rm -rf "$vgrp"
fi
lvm vgcreate --physicalextentsize ${extentsize}k ${vgrp#/dev/} ${devices[@]} >&2
lvm vgchange --available y ${vgrp#/dev/} >&2
EOF
}

# Restore a VG from a backup.
restore_lvmgrp() {
    local lvmgrp vgrp extentsize junk
    read lvmgrp vgrp extentsize junk < <(grep "^lvmgrp $1 " "$LAYOUT_FILE")
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Restoring LVM VG ${vgrp#/dev/}"
if [ -e "$vgrp" ] ; then
    rm -rf "$vgrp"
fi
lvm vgcfgrestore -f "$VAR_DIR/layout/lvm/${vgrp#/dev/}.cfg" ${vgrp#/dev/} >&2
lvm vgchange --available y ${vgrp#/dev/} >&2
EOF
}

# Create a LV.
create_lvmvol() {
    if [ -z "$MIGRATION_MODE" ] ; then
        return
    fi

    local name vg lv
    name=${1#/dev/mapper/}
    ### split between vg and lv is single dash
    ### Device mapper doubles dashes in vg and lv
    vg=$(sed "s/\([^-]\)-[^-].*/\1/;s/--/-/g" <<< "$name")
    lv=$(sed "s/.*[^-]-\([^-]\)/\1/;s/--/-/g" <<< "$name")

    local lvmvol vgrp lvname nrextents junk
    read lvmvol vgrp lvname nrextents junk < <(grep "^lvmvol /dev/$vg $lv " "$LAYOUT_FILE")

    (
    echo "LogPrint \"Creating LVM volume ${vgrp#/dev/}/$lvname\""
    echo "lvm lvcreate -l $nrextents -n ${lvname} ${vgrp#/dev/} >&2"
    ) >> "$LAYOUT_CODE"
}
