# Utility functions for the system layout processing

DATE=$(date +%Y%m%d)

BACKUPS_TAKEN=()

# Copy file $1 to $1.$DATE
backup_file() {
    if ! IsInArray "$1" "${BACKUPS_TAKEN[@]}" ; then
        cp -ar $1 $1.$DATE.$$.bak
        BACKUPS_TAKEN=( "${BACKUPS_TAKEN[@]}" "$1" )
    fi
}

# Restore the backup of $1
restore_backup() {
    cp -ar $1.$DATE.$$.bak $1
}

# generate code to restore a device $1 of type $2
# Note that we do not handle partitioning here.
create_device() {
    local device=$1
    local type=$2
    local name # used to extract the actual name of the device

    cat <<EOF >> $LAYOUT_CODE
if create_component "$device" "$type" ; then
EOF
    echo "# Create $device ($type)">> $LAYOUT_CODE
    case "$type" in
        disk)
            partition_disk <(grep "^disk $device" $LAYOUT_FILE)
            ;;
        part)
            # Partitions depend on disks, "disk" creates all partitions at once
            ;;
        lvmdev)
            name=${device#pv:}
            create_lvmdev <(grep "^lvmdev.*$name" $LAYOUT_FILE)
            ;;
        lvmgrp)
            if [ -z "$MIGRATION_MODE" ] ; then
                restore_lvmgrp <(grep "^lvmgrp $device" $LAYOUT_FILE)
            else
                create_lvmgrp <(grep "^lvmgrp $device" $LAYOUT_FILE)
            fi
            ;;
        lvmvol)
            if [ -n "$MIGRATION_MODE" ] ; then
                name=${device#/dev/mapper/}
                dm_vg=${name%-*}
                # Device mapper doubles dashes
                vg=${dm_vg/--/-}
                lv=${name##*-}
                create_lvmvol <(grep "^lvmvol /dev/$vg $lv" $LAYOUT_FILE)
            fi
            ;;
        raid)
            create_raid <(grep "^raid $device" $LAYOUT_FILE)
            ;;
        fs)
            name=${device#fs:}
            create_fs <(grep "^fs.* $name " $LAYOUT_FILE)
            ;;
        swap)
            name=${device#swap:}
            create_swap <(grep "^swap $name " $LAYOUT_FILE)
            ;;
        drbd)
            create_drbd <(grep "^drbd $device" $LAYOUT_FILE)
            ;;
        crypt)
            create_crypt <(grep "^crypt $device" $LAYOUT_FILE)
            ;;
        smartarray)
            name=${device#sma:}
            create_smartarray <(grep "^smartarray $name" $LAYOUT_FILE)
            ;;
        logicaldrive)
            name=${device#ld:}
            create_logicaldrive <(grep "^logicaldrive $name" $LAYOUT_FILE)
            ;;
    esac
    cat <<EOF >> $LAYOUT_CODE
component_created "$device" "$type"
else
    LogPrint "Skipping $device ($type) as it has already been created."
fi

EOF
}

abort_recreate() {
    Log "Error detected during restore."
    Log "Restoring backup of $LAYOUT_FILE"
    restore_backup "$LAYOUT_FILE"
}

# Test and log if a component $1 (type $2) needs to be recreated.
create_component() {
    local device=$1
    local type=$2
    # if a touchfile already exists, no need to recreate this component
    local touchfile="$type-${device//\//-}"
    if [ -e $LAYOUT_TOUCHDIR/$touchfile ] ; then
        return 1
    else
        return 0
    fi
}

# Mark a component as created
component_created() {
    local device=$1
    local type=$2
    # Create a touchfile
    local touchfile="$type-${device//\//-}"
    touch $LAYOUT_TOUCHDIR/$touchfile
}

# Mark device $1 as done.
mark_as_done() {
    Log "Marking $1 as done."
    sed -i "s;todo\ $1\ ;done\ $1\ ;" $LAYOUT_TODO
}

# Mark all devices that depend on $1 as done.
mark_tree_as_done() {
    local devlist="$1 "
    while [ -n "$devlist" ] ; do
        testdev=$(echo "$devlist" | cut -d " " -f "1")
        while read dev on junk ; do
            if [ "$on" = "$testdev" ] ; then
                Log "Marking $testdev as done (dependent on $1)"
                devlist="$devlist$dev "
                mark_as_done "$dev"
            fi
        done < <(cat $LAYOUT_DEPS)
        devlist=$(echo "$devlist" | sed -r "s;^$testdev ;;")
    done
}

# find_devices <other>
# Find the disk device(s) component $1 resides on.
find_disk() {
    echo "$(get_parent_components "disk" $1)" | sort | uniq
}

find_partition() {
    echo "$(get_parent_components "part" $1)" | sort | uniq
}

# Find all disk devices component $1 resides on.
# Can/will contain multiples.
get_parent_components() {
    local component type
    local components=$(get_parent_component $2)

    for component in $components ; do
        type=$(get_component_type $component)
        if [ "$type" = "$1" ] ; then
            echo "$component"
        else
            get_parent_components $1 $component
        fi
    done
}

# Read the parent component(s) from the layout deps list
get_parent_component() {
    grep "^$1 " $LAYOUT_DEPS | cut -d " " -f 2 | sort | uniq
}

# Get the type of a layout component
get_component_type() {
    grep -E "^[^ ]+ $1 " $LAYOUT_TODO | cut -d " " -f 3
}

# Function returns 0 when v1 is greater or equal than v2
version_newer() {
  local v1list=( ${1//[-.]/ } )
  local v2list=( ${2//[-.]/ } )

  ### Take largest
  local max=${#v1list[@]}
  if (( $max < ${#v2list[@]} )); then
    max=${#v2list[@]}
  fi

  local pos
  for pos in $(seq 0 $(( max -1 ))); do
    ### Arithmetic comparison
    if (( 10#0${v1list[$pos]} >= 0 && 10#0${v2list[$pos]} >= 0 )) 2>/dev/null; then
#      echo "pos $pos: arithm ${v1list[$pos]} vs ${v2list[$pos]}"
      if (( 10#0${v1list[$pos]} < 10#0${v2list[$pos]} )); then
        return 1
      elif (( 10#0${v1list[$pos]} > 10#0${v2list[$pos]} )); then
        return 0
      fi
    ### String comparison
    else
#      echo "pos $pos: string ${v1list[$pos]} vs ${v2list[$pos]}"
      if [[ "${v1list[$pos]}" < "${v2list[$pos]}" ]]; then
        return 1
      elif [[ "${v1list[$pos]}" > "${v2list[$pos]}" ]]; then
        return 0
      fi
    fi
  done

  return 0
}

# Function to get version from tool
get_version() {
  $@ 2>&1 | sed -rn 's/^[^0-9\.]*([0-9]+\.[-0-9a-z\.]+).*$/\1/p' | head -1
}

# Get the device mapper name of a device
get_friendly_name() {
    # strip /dev/ from the front of the input
    local search=${1#/dev/}

    # Compare device numbers on the input device and the mapper devices
    local number=$(stat -L -c "%t:%T" /dev/$search )
    [ "$number" ]
    BugIfError "Unknown device..."

    local device
    for device in /dev/mapper/* ; do
        local test=$(stat -L -c "%t:%T" $device)
        if [ "$test" = "$number" ] ; then
            echo ${device#/dev/}
            return 0
        fi
    done
    
    echo "$search"
}

# Translate a device name to a sysfs name.
get_sysfs_name() {
    local name=${1#/dev/}
    name=${name#/sys/block/}
    echo "${name//\//!}"
}

# Translate a sysfs name to a device name.
get_device_name() {
    local name=$(get_sysfs_name $1)
    echo "${name//!//}"
}

# Get the size in bytes of a block device.
get_disk_size() {
    local disk_name=$(get_sysfs_name $1)
    
    # Only newer kernels have an interface to get the block size
    if [ -r /sys/block/$disk_name/queue/logical_block_size ] ; then
        local block_size=$(cat /sys/block/$disk_name/queue/logical_block_size)
    else
        local block_size=512
    fi
    
    [ -r /sys/block/$disk_name/size ]
    BugIfError "Could not determine size of disk $disk_name, please file a bug."

    local nr_blocks=$(cat /sys/block/$disk_name/size)
    local disk_size=$(( nr_blocks * block_size ))
    
    ### Make sure we always return a number
    echo $(( disk_size ))
}
