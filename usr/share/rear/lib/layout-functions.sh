# Utility functions for the system layout processing.

DATE=$(date +%Y%m%d)
# FIXME: Why not using ISO 8601 date? $(date +%F)

BACKUPS_TAKEN=()

# Copy file $1 to $1.$DATE.
backup_file() {
    if [[ ! -r "$1" ]]; then
        return
    elif ! IsInArray "$1" "${BACKUPS_TAKEN[@]}" ; then
        cp -ar $1 $1.$DATE.$$.bak
        BACKUPS_TAKEN=( "${BACKUPS_TAKEN[@]}" "$1" )
    fi
}

# Restore the backup of $1
restore_backup() {
    cp -ar $1.$DATE.$$.bak $1
}

# Generate code to restore a device $1 of type $2.
# Note that we do not handle partitioning here.
create_device() {
    local device="$1"
    local type="$2"
    local name # used to extract the actual name of the device

    cat <<EOF >> "$LAYOUT_CODE"
if create_component "$device" "$type" ; then
EOF
    echo "# Create $device ($type)" >> "$LAYOUT_CODE"
    if type -t create_$type >&8 ; then
        create_$type "$device"
    fi
    cat <<EOF >> "$LAYOUT_CODE"
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
    local device="$1"
    local type="$2"
    # If a touchfile already exists, no need to recreate this component.
    local touchfile="$type-${device//\//-}"
    if [ -e "$LAYOUT_TOUCHDIR/$touchfile" ] ; then
        return 1
    else
        return 0
    fi
}

# Mark a component as created.
component_created() {
    local device=$1
    local type=$2
    # Create a touchfile.
    local touchfile="$type-${device//\//-}"
    touch "$LAYOUT_TOUCHDIR/$touchfile"
}

# Generate dependencies between disks as found in $LAYOUT_FILE.
# This will be written to $LAYOUT_DEPS.
# Also generate a list of disks to be restored in $LAYOUT_TODO.
generate_layout_dependencies() {
    # $LAYOUT_DEPS is a list of:
    # <item> <depends on>
    : > $LAYOUT_DEPS

    # $LAYOUT_TODO is a list of:
    # [todo|done] <type> <item>
    : > $LAYOUT_TODO

    local type dev remainder name disk disks vgrp dm_vgrp lvol dm_lvol part mp fs bd nmp temp_nm
    while read type remainder ; do
        case $type in
            disk)
                name=$(echo "$remainder" | cut -d " " -f "1")
                add_component "$name" "disk"
                ;;
            part)
                # disk is the first field of the remainder
                disk=$(echo "$remainder" | cut -d " " -f "1")
                name=$(echo "$remainder" | cut -d " " -f "6")
                add_dependency "$name" "$disk"
                add_component "$name" "part"
                ;;
            lvmgrp)
                name=$(echo "$remainder" | cut -d " " -f "1")
                add_component "$name" "lvmgrp"
                ;;
            lvmdev)
                vgrp=$(echo "$remainder" | cut -d " " -f "1")
                part=$(echo "$remainder" | cut -d " " -f "2")
                add_dependency "$vgrp" "pv:$part"
                add_dependency "pv:$part" "$part"
                add_component "pv:$part" "lvmdev"
                ;;
            lvmvol)
                vgrp=$(echo "$remainder" | cut -d " " -f "1")
                lvol=$(echo "$remainder" | cut -d " " -f "2")

                # Vgs and Lvs containing - in their name have a double dash in DM
                dm_vgrp=${vgrp//-/--}
                dm_lvol=${lvol//-/--}

                add_dependency "/dev/mapper/${dm_vgrp#/dev/}-$dm_lvol" "$vgrp"
                add_component "/dev/mapper/${dm_vgrp#/dev/}-$dm_lvol" "lvmvol"
                ;;
            raid)
                name=$(echo "$remainder" | cut -d " " -f "1")
                disks=( $(echo "$remainder" | sed -r "s/.*devices=([^ ]+).*/\1/" | tr ',' ' ') )
                for disk in "${disks[@]}" ; do
                    add_dependency "$name" "$disk"
                done
                add_component "$name" "raid"
                ;;
            fs)
                dev=$(echo "$remainder" | cut -d " " -f "1")
                mp=$(echo "$remainder" | cut -d " " -f "2")
                add_dependency "fs:$mp" "$dev"
                add_component "fs:$mp" "fs"

                # find dependencies on other filesystems
                while read fs bd nmp junk; do
                    if [ "$nmp" != "/" ] ; then
                        # make sure we only match complete paths
                        # e.g. not /data as a parent of /data1
                        temp_nmp="$nmp/"
                    else
                        temp_nmp="$nmp"
                    fi

                    if [ "${mp#$temp_nmp}" != "${mp}" ] && [ "$mp" != "$nmp" ]; then
                        add_dependency "fs:$mp" "fs:$nmp"
                    fi
                done < <(grep "^fs" $LAYOUT_FILE)
                ;;
            swap)
                dev=$(echo "$remainder" | cut -d " " -f "1")
                add_dependency "swap:$dev" "$dev"
                add_component "swap:$dev" "swap"
                ;;
            drbd)
                dev=$(echo "$remainder" | cut -d " " -f "1")
                disk=$(echo "$remainder" | cut -d " " -f "3")
                add_dependency "$dev" "$disk"
                add_component "$dev" "drbd"
                ;;
            crypt)
                name=$(echo "$remainder" | cut -d " " -f "1")
                device=$(echo "$remainder" | cut -d " " -f "2")
                add_dependency "$name" "$device"
                add_component "$name" "crypt"
                ;;
            multipath)
                name=$(echo "$remainder" | cut -d " " -f "1")
                disks=$(echo "$remainder" | cut -d " " -f "2" | tr "," " ")

                add_component "$name" "multipath"

                for disk in $disks ; do
                    add_dependency "$name" "$disk"
                done
                ;;
        esac
    done < <(cat $LAYOUT_FILE)
}

# Add a dependency from one component on another
# add_dependency <from> <on>
add_dependency() {
    echo "$1 $2" >> $LAYOUT_DEPS
}

# Add a component to be restored
# add_component <name> <type>
# The name must be equal to the one used in dependency resolution
# The type is needed to restore the component.
add_component() {
    echo "todo $1 $2" >> $LAYOUT_TODO
}

# Mark device $1 as done.
mark_as_done() {
    Debug "Marking $1 as done."
    sed -i "s;todo\ $1\ ;done\ $1\ ;" $LAYOUT_TODO
}

# Mark all devices that depend on $1 as done.
mark_tree_as_done() {
    for component in $(get_child_components "$1") ; do
        Debug "Marking $component as done (dependent on $1)"
        mark_as_done "$component"
    done
}

# Return all the (grand-)child components of $1 [filtered by type $2]
get_child_components() {
    declare -a devlist children
    declare current child parent

    devlist=( "$1" )
    while (( ${#devlist[@]} )) ; do
        current=${devlist[0]}

        ### Find all direct child elements of the current component...
        while read child parent junk ; do
            if [[ "$parent" = "$current" ]] ; then
                ### ...and add them to the list
                if IsInArray "$child" "${children[@]}" ; then
                    continue
                fi
                devlist=( "${devlist[@]}" "$child" )
                children=( "${children[@]}" "$child" )
            fi
        done < $LAYOUT_DEPS

        ### remove the current element from the array and re-index it
        unset "devlist[0]"
        devlist=( "${devlist[@]}" )
    done

    ### Filter for the wanted type
    declare component type
    for component in "${children[@]}" ; do
        if [[ "$2" ]] ; then
            type=$(get_component_type "$component")
            if [[ "$type" != "$2" ]] ; then
                continue
            fi
        fi
        echo "$component"
    done
}

# Return all ancestors of component $1 [ of type $2 ]
get_parent_components() {
    declare -a ancestors devlist
    declare current child parent

    devlist=( "$1" )
    while (( ${#devlist[@]} )) ; do
        current=${devlist[0]}

        ### Find all direct parent elements of the current component...
        while read child parent junk ; do
            if [[ "$child" = "$current" ]] ; then
                ### ...test if we visited them already...
                if IsInArray "$parent" "${ancestors[@]}" ; then
                    continue
                fi
                ### ...and add them to the list
                devlist=( "${devlist[@]}" "$parent" )
                ancestors=( "${ancestors[@]}" "$parent" )
            fi
        done < $LAYOUT_DEPS

        ### remove the current element from the array and re-index it
        unset "devlist[0]"
        devlist=( "${devlist[@]}" )
    done

    ### Filter the ancestors for the correct type.
    declare component type
    for component in "${ancestors[@]}" ; do
        if [[ "$2" ]] ; then
            type=$(get_component_type "$component")
            if [[ "$type" != "$2" ]] ; then
                continue
            fi
        fi
        echo "$component"
    done
}

# find_devices <other>
# Find the disk device(s) component $1 resides on.
find_disk() {
    get_parent_components "$1" "disk"
}

find_disk_and_multipath() {
    res=$(find_disk "$1")
    if [[ -n "$res" || "$AUTOEXCLUDE_MULTIPATH" =~ ^[yY1] ]]; then
        echo $res
    else
        find_multipath "$1"
    fi
}

find_multipath() {
    get_parent_components "$1" "multipath"
}

find_partition() {
    get_parent_components "$1" "part"
}

# Function returns partition number of partition block device name
#
# This function should support:
#   /dev/mapper/36001438005deb05d0000e00005c40000p1
#   /dev/mapper/36001438005deb05d0000e00005c40000_part1
#   /dev/sda1
#   /dev/cciss/c0d0p1
#
# Requires: grep v2.5 or higher (option -o)

get_partition_number() {
    local partition=$1
    local number=$(echo "$partition" | grep -o -E "[0-9]+$")

    # Test if $number is a positive integer, if not it is a bug
    [ $number -gt 0 ] 2>&8
    StopIfError "Partition number '$number' of partition $partition is not a valid number."

    # Catch if $number is too big, report it as a bug
    (( $number <= 128 ))
    StopIfError "Partition $partition is numbered '$number'. More than 128 partitions is not supported."

    echo $number
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

# Function to get version from tool.
get_version() {
  TERM=dumb $@ 2>&1 | sed -rn 's/^[^0-9\.]*([0-9]+\.[-0-9a-z\.]+).*$/\1/p' | head -1
}

# Translate a device name to a sysfs name.
get_sysfs_name() {
    local name=${1#/dev/}
    name=${name#/sys/block/}

    if [[ -e /sys/block/${name//\//!} ]] ; then
        echo "${name//\//!}"
        return 0
    fi

    ### Follow symlinks.
    if [[ -h /dev/$name ]] ; then
        local target=$(readlink -f /dev/$name)
        if [[ -e /sys/block/${target#/dev/} ]] ; then
            echo "${target#/dev/}"
            return 0
        fi
    fi

    # Accommodate for mapper/test -> dm-? mapping.
    local dev_number=$(dmsetup info -c --noheadings -o major,minor ${name##*/} 2>&8 )
    if [[ "$dev_number" ]] ; then
        local dev_name sysfs_device
        for sysfs_device in /sys/block/*/dev ; do
            if [[ "$dev_number" = "$( < $sysfs_device)" ]] ; then
                dev_name=${sysfs_device#/sys/block/}
                echo "${dev_name%/*}"
                return 0
            fi
        done
    fi

    # Otherwise, it can be the case that we just want to translate the name.
    echo "${name//\//!}"
    return 1
}

### Translate a sysfs name or device name to the name preferred in
### Relax-and-Recover.
### The device does not necessarily exist.
###     cciss!c0d0 -> /dev/cciss/c0d0
###     /dev/dm-3 -> /dev/mapper/system-tmp
###     /dev/dm-4 -> /dev/mapper/oralun
###     /dev/dm-5 -> /dev/mapper/oralunp1
get_device_name() {
    ### strip common prefixes
    local name=${1#/dev/}
    name=${name#/sys/block/}

    [[ "$name" ]]
    BugIfError "Empty string passed to get_device_name"

    ### Translate dm-8 -> mapper/test
    local device dev_number mapper_number
    if [[ -d /sys/block/$name ]] ; then
        if [[ -r /sys/block/$name/dm/name ]] ; then
            ### recent kernels have a dm subfolder
            echo "/dev/mapper/$( < /sys/block/$name/dm/name)";
            return 0
        else
            ### loop over all block devices
            dev_number=$( < /sys/block/$name/dev)
            for device in /dev/mapper/* ; do
                mapper_number=$(dmsetup info -c --noheadings -o major,minor ${device#/dev/mapper/} 2>&8 )
                if [ "$dev_number" = "$mapper_number" ] ; then
                    echo "$device"
                    return 0
                fi
            done
        fi
    fi

    ### Translate device name to mapper name. ex: vg/lv -> mapper/vg-lv
    if [[ "$name" =~ ^mapper/ ]]; then
        echo "/dev/$name"
        return 0
    fi
    if my_dm=`readlink /dev/$name`; then
       for mapper_dev in /dev/mapper/*; do
           if mapper_dm=`readlink $mapper_dev`; then
              if [ "$my_dm" = "$mapper_dm" ]; then
                 echo $mapper_dev
                 return 0
              fi
           fi
       done
    fi

    ### handle cciss sysfs naming
    name=${name//!//}

    ### just return the possibly nonexisting name
    echo "/dev/$name"
    return 1
}

# check $VAR_LIB/recovery/diskbyid_mappings file to see whether we find
# a disk/by-id mapping to dm style (the by-id dev is not translated
# properly by get_device_name function - dm dev are better)
# 22_lvm_layout.sh uses get_device_mapping to translate lvmdev better
### ciss-3600508b1001fffffa004f7b3f209000b-part2 -> cciss/c0d0p2
# see issue #305
get_device_mapping() {
    if [[ ! -s "${VAR_DIR}/recovery/diskbyid_mappings" ]]; then
        echo $1
    else
        local name=${1##*/}      # /dev/disk/by-id/scsi-xxxx -> scsi-xxx
        local disk_name=$(grep "^${name}" ${VAR_DIR}/recovery/diskbyid_mappings | awk '{print $2}')
        if [[ -z "$disk_name" ]]; then
            echo $1
        else
            echo "/dev/$disk_name"
        fi
    fi
}

# Get the size in bytes of a disk/partition.
# For partitions, use "sda/sda1" as argument.
get_disk_size() {
    local disk_name=$1

    local block_size=$(get_block_size ${disk_name%/*})

    [ -r /sys/block/$disk_name/size ]
    BugIfError "Could not determine size of disk $disk_name, please file a bug."

    local nr_blocks=$( < /sys/block/$disk_name/size)
    local disk_size=$(( nr_blocks * block_size ))

    ### Make sure we always return a number
    echo $(( disk_size ))
}

# Get the block size of a disk.
get_block_size() {
    # Only newer kernels have an interface to get the block size
    if [ -r /sys/block/$1/queue/logical_block_size ] ; then
        echo $( < /sys/block/$1/queue/logical_block_size)
    else
        echo "512"
    fi
}

# Get the UUID of a device.
# Device is something like /dev/sda1.
blkid_uuid_of_device() {
    local device=$1
    local uuid=""
    for LINE in $(blkid $device  2>/dev/null)
    do
        uuid=$( echo "$LINE" | grep "^UUID=" | cut -d= -f2 | sed -e 's/"//g')
        [[ ! -z "$uuid" ]] && break
    done
    echo "$uuid"
}

