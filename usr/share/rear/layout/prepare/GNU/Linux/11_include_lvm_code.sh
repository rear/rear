# Code to recreate an LVM configuration
# The input to the code creation functions is a file descriptor to one line
# of the layout description.

if ! type -p lvm &>/dev/null ; then
    return
fi

# Test for features in lvm
# Versions higher than 2.02.73 need --norestorefile if no UUID/restorefile
FEATURE_LVM_RESTOREFILE=

lvm_version=$(get_version lvm version)

if [ -z "$lvm_version" ] ; then
    BugError "Function get_version could not detect lvm version."
elif version_newer "$lvm_version" 2.02.73 ; then
    FEATURE_LVM_RESTOREFILE="y"
fi

# Create a new PV
create_lvmdev() {
    read lvmdev vgrp device uuid junk < $1
    
    (
    echo "LogPrint \"Creating LVM PV $device\""
    uuidopt=""
    restorefileopt=""
    
    if [ -z "$MIGRATION_MODE" ] && [ -e $VAR_DIR/layout/lvm/${vgrp#/dev/}.cfg ] ; then
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
    echo "lvm pvcreate -ff --yes -v$uuidopt$restorefileopt $device 1>&2"
    ) >> $LAYOUT_CODE
}

# Create a new VG
create_lvmgrp() {
    read lvmgrp vgrp extentsize junk < $1
    
    devices=($(grep "^lvmdev $vgrp" $LAYOUT_FILE | cut -d " " -f 3))
    
cat >> $LAYOUT_CODE <<EOF
LogPrint "Creating LVM VG ${vgrp#/dev/}"
if [ -e $vgrp ] ; then
    rm -rf $vgrp
fi
lvm vgcreate --physicalextentsize ${extentsize}k ${vgrp#/dev/} ${devices[@]} 1>&2
lvm vgchange --available y ${vgrp#/dev/} 1>&2
EOF
}

# Restore a VG from a backup
restore_lvmgrp() {
    read lvmgrp vgrp extentsize junk < $1
cat >> $LAYOUT_CODE <<EOF
LogPrint "Restoring LVM VG ${vgrp#/dev/}"
if [ -e $vgrp ] ; then
    rm -rf $vgrp
fi
lvm vgcfgrestore -f $VAR_DIR/layout/lvm/${vgrp#/dev/}.cfg ${vgrp#/dev/} 1>&2
lvm vgchange --available y ${vgrp#/dev/} 1>&2
EOF
}

# Create a LV
create_lvmvol() {
    read lvmvol vgrp lvname nrextents junk < $1
    
    (
    echo "LogPrint \"Creating LVM volume ${vgrp#/dev/}/$lvname\""
    echo "lvm lvcreate -l $nrextents -n ${lvname} ${vgrp#/dev/} 1>&2"
    ) >> $LAYOUT_CODE
}
