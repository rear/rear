# Code to recreate an LVM configuration.
# The input to the code creation functions is a file descriptor to one line
# of the layout description.

if ! has_binary lvm; then
    return
fi

#
# Refer to usr/share/rear/layout/save/GNU/Linux/220_lvm_layout.sh for the
# corresponding information collected during 'mkrescue'.
#

# Test for features in lvm.
# Versions higher than 2.02.73 need --norestorefile if no UUID/restorefile.
FEATURE_LVM_RESTOREFILE=

lvm_version=$(get_version lvm version)

[ "$lvm_version" ] || BugError "Function get_version could not detect lvm version."

# RHEL 6.0 contains lvm with knowledge of --norestorefile (issue #462)
if version_newer "$lvm_version" 2.02.71 ; then
    FEATURE_LVM_RESTOREFILE="y"
fi

# Create a new PV.
create_lvmdev() {
    local lvmdev vgrp device uuid junk
    # Selects line matching 'lvmdev' (PV) and disk name (column 3),
    # cf. https://github.com/rear/rear/pull/1897
    # This should be unique.
    read lvmdev vgrp device uuid junk < <(awk "\$1 == \"lvmdev\" && \$3 == \"${1#pv:}\" { print }" "$LAYOUT_FILE")

    local vg=${vgrp#/dev/}

    (
    echo "LogPrint \"Creating LVM PV $device\""

    ### Work around automatic volume group activation leading to active disks
    echo "lvm vgchange -a n $vg || true"

    local uuidopt=""
    local restorefileopt=""

    if ! is_true "$MIGRATION_MODE" && test -e "$VAR_DIR/layout/lvm/${vg}.cfg" ; then
        # we have a restore file
        restorefileopt=" --restorefile $VAR_DIR/layout/lvm/${vg}.cfg"
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
    local lvmgrp vgrp extentsize junk
    read lvmgrp vgrp extentsize junk < <(grep "^lvmgrp $1 " "$LAYOUT_FILE")

    local vg=${vgrp#/dev/}

    # If a volume group name is in one of the following lists, it
    # means that the particular condition is valid for this volume
    # grup. If it is not in the list, it means that the condition is
    # not valid for this volume group. To set a condition, add the VG
    # name to the list. To unset it, remove it from the list.

    # We must represent the conditions using lists, not simple scalar
    # boolean variables. The conditions shall propagate information
    # from VG creation to LV creation. A scalar does not work well in
    # the case of multiple VGs, because the variables are global and
    # if there are multiple VGs, their values will leak from one VG to
    # another. (The generated diskrestore.sh script does not guarantee
    # that the LVs of a given VG are created immediately after their
    # VG and before creating another VG, actually, the script first
    # creates all VGs and then all LVs.)  This logic does not apply to
    # the create_volume_group condition, because it is local to the VG
    # creation and does not need to be propagated to LV creation. We
    # use the same approach for symmetry, though.

    # The meanings of conditions corresponding to those lists are:
    # create_volume_group - VG needs to be created using the vgcreate command
    # create_logical_volumes - LVs in the VG need to be created using the lvcreate command
    # create_thin_volumes_only - when the previous condition is true,
    #   do not create volumes that are not thin volumes.

    cat >> "$LAYOUT_CODE" <<EOF
create_volume_group+=( "$vg" )
create_logical_volumes+=( "$vg" )
create_thin_volumes_only=( \$( RmInArray "$vg" "\${create_thin_volumes_only[@]}" ) )

EOF

    # If we are not migrating, then try using "vgcfgrestore", but this can
    # fail, typically if Thin Pools are used.
    #
    # In such case, we need to rely on vgcreate/lvcreate commands which is not
    # recommended because we are not able to collect all required options yet.
    # For example, we do not take the '--stripes' option into account, nor
    # '--mirrorlog', etc.
    # Also, we likely do not support every layout yet (e.g. 'cachepool').

    if ! is_true "$MIGRATION_MODE" ; then
        cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Restoring LVM VG '$vg'"
if [ -e "$vgrp" ] ; then
    rm -rf "$vgrp"
fi
#
# Restore layout using 'vgcfgrestore', this may fail if there are Thin volumes
#
if lvm vgcfgrestore -f "$VAR_DIR/layout/lvm/${vg}.cfg" $vg >&2 ; then
    lvm vgchange --available y $vg >&2

    LogPrint "Sleeping 3 seconds to let udev or systemd-udevd create their devices..."
    sleep 3 >&2
    create_volume_group=( \$( RmInArray "$vg" "\${create_volume_group[@]}" ) )
    create_logical_volumes=( \$( RmInArray "$vg" "\${create_logical_volumes[@]}" ) )

#
# It failed ... restore layout using 'vgcfgrestore --force', but then remove Thin volumes, they are broken
#
elif lvm vgcfgrestore --force -f "$VAR_DIR/layout/lvm/${vg}.cfg" $vg >&2 ; then

    lvm lvs --noheadings -o lv_name,vg_name,lv_layout | while read lv vg layout ; do
        # Consider LVs for our VG only
        [ \$vg == "$vg" ] || continue
        # Consider Thin Pools only
        [[ ,\$layout, == *,thin,* ]] && [[ ,\$layout, == *,pool,* ]] || continue
        # Use "--force" twice to bypass any error due to invalid transaction id
        lvm lvremove -q -f -f -y $vg/\$lv
    done

    # Once Thin pools have been removed, we can activate the VG
    lvm vgchange --available y $vg >&2

    LogPrint "Sleeping 3 seconds to let udev or systemd-udevd create their devices..."
    sleep 3 >&2

    # All logical volumes have been created, except Thin volumes and pools
    create_volume_group=( \$( RmInArray "$vg" "\${create_volume_group[@]}" ) )
    create_thin_volumes_only+=( "$vg" )
 
#
# It failed also ... restore using 'vgcreate/lvcreate' commands
#
else
    LogPrint "Could not restore LVM configuration using 'vgcfgrestore'. Using traditional 'vgcreate/lvcreate' commands instead"
fi

EOF
    fi

    # Cf. https://github.com/rear/rear/pull/1897
    local -a devices=($(awk "\$1 == \"lvmdev\" && \$2 == \"$vgrp\" { print \$3 }" "$LAYOUT_FILE"))

cat >> "$LAYOUT_CODE" <<EOF
if IsInArray $vg "\${create_volume_group[@]}" ; then
    LogPrint "Creating LVM VG '$vg' (some properties may not be preserved)"
    lvm vgremove --force --force --yes $vg >&2 || true
    if [ -e "$vgrp" ] ; then
        rm -rf "$vgrp"
    fi
    lvm vgcreate --physicalextentsize ${extentsize}k $vg ${devices[@]} >&2
    lvm vgchange --available y $vg >&2
fi
EOF
}

# Create a LV.
create_lvmvol() {
    local name vg lv
    name=${1#/dev/mapper/}
    ### split between vg and lv is single dash
    ### Device mapper doubles dashes in vg and lv
    vg=$(sed "s/\([^-]\)-[^-].*/\1/;s/--/-/g" <<< "$name")
    lv=$(sed "s/.*[^-]-\([^-]\)/\1/;s/--/-/g" <<< "$name")

    # kval: "key:value" pairs, separated by spaces
    local lvmvol vgrp lvname size layout kval
    read lvmvol vgrp lvname size layout kval < <(grep "^lvmvol /dev/$vg $lv " "$LAYOUT_FILE")

    local lvopts=""

    # Handle 'key:value' pairs
    for kv in $kval ; do
        local key=$(awk -F ':' '{ print $1 }' <<< "$kv")
        local value=$(awk -F ':' '{ print $2 }' <<< "$kv")
        lvopts="${lvopts:+$lvopts }--$key $value"
    done

    local is_thin=0
    local is_raidunknown=0

    if [[ ,$layout, == *,thin,* ]] ; then

        is_thin=1

        if [[ ,$layout, == *,pool,* ]] ; then
            # Thin Pool

            lvopts="${lvopts:+$lvopts }--type thin-pool -L $size --thinpool $lv"

        else
            # Thin Volume within Thin Pool

            if [[ ,$layout, == *,sparse,* ]] ; then
                lvopts="${lvopts:+$lvopts }-V $size -n ${lvname}"
            else
                BugError "Unsupported Thin LV layout '$layout' for LV '$lv'"
            fi

        fi

    elif [[ ,$layout, == *,linear,* ]] ; then

        lvopts="${lvopts:+$lvopts }-L $size -n ${lvname}"

    elif [[ ,$layout, == *,mirror,* ]] ; then

        lvopts="${lvopts:+$lvopts }--type mirror -L $size -n ${lvname}"

    elif [[ ,$layout, == *,striped,* ]] ; then

        lvopts="${lvopts:+$lvopts }--type striped -L $size -n ${lvname}"

    elif [[ ,$layout, == *,raid,* ]] ; then

        local found=0
        local lvl
        for lvl in raid0 raid1 raid4 raid5 raid6 raid10 ; do
            if [[ ,$layout, == *,$lvl,* ]] ; then
                lvopts="${lvopts:+$lvopts }--type $lvl"
                found=1
                break
            fi
        done

        if [ $found -eq 0 ] ; then
            if [[ ,$layout, == *,RAID_UNKNOWNTYPE,* ]] ; then
                # Compatibility with older LVM versions (e.g. <= 2.02.98)
                is_raidunknown=1
                # Don't set '--type', so will be created as a linear volume
            else
                BugError "Unsupported LV layout '$layout' found for LV '$lv'"
            fi
        fi

        lvopts="${lvopts:+$lvopts }-L $size -n ${lvname}"

    else

        BugError "Unsupported LV layout '$layout' found for LV '$lv'"

    fi

    local ifline
    local warnraidline

    if [ $is_thin -eq 0 ] ; then
        ifline="if IsInArray $vg \"\${create_logical_volumes[@]}\" && ! IsInArray $vg \"\${create_thin_volumes_only[@]}\" ; then"
    else
        ifline="if IsInArray $vg \"\${create_logical_volumes[@]}\" ; then"
    fi

    if [ $is_raidunknown -eq 1 ]; then
        warnraidline="LogPrint \"Warning: Don't know how to restore RAID volume '$lv', restoring as linear volume\""
    else
        warnraidline=""
    fi

    local fallbacklvopts
    # Assume lvcreate had failed because of "Volume group ... has insufficient free space"
    # which usually happens when the replacement disk is a bit smaller than the original disk
    # so that the following fallback attempt to create a LV could work at least once per VG
    # which is sufficient when the replacement disk is a bit smaller than the original disk
    # because then the last LV that is created gets shrinked to the remaining space in the VG.
    # In the lvopts string replace the exact size option of the form '-L 123456b'
    # with an option to use all remaining free space in the VG via '-l 100%FREE'
    # so e.g. 'lvcreate -L 123456b -n LV VG' becomes 'lvcreate -l 100%FREE -n LV VG'
    fallbacklvopts="$( sed -e 's/-L [0-9b]*/-l 100%FREE/' <<< "$lvopts" )"

    cat >> "$LAYOUT_CODE" <<EOF
$ifline
    LogPrint "Creating LVM volume '$vg/$lvname' (some properties may not be preserved)"
    $warnraidline
    if ! lvm lvcreate -y $lvopts $vg ; then
        LogPrintError "Failed to create LVM volume '$vg/$lvname' with lvcreate -y $lvopts $vg"
        if lvm lvcreate -y $fallbacklvopts $vg ; then
            LogPrintError "Created LVM volume '$vg/$lvname' using fallback options lvcreate -y $fallbacklvopts $vg"
        else
            LogPrintError "Also failed to create LVM volume '$vg/$lvname' with lvcreate -y $fallbacklvopts $vg"
            # Explicit 'false' is needed to let the whole 'if then else fi' command exit with non zero exit state
            # to let diskrestore.sh abort here as usual when a command fails (diskrestore.sh runs with 'set -e'):
            false
        fi
    fi
fi
EOF
}

# vim: set et ts=4 sw=4:
