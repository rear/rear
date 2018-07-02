# Utility functions for the system layout processing.

# TODO: Why not using ISO 8601 date 'date +%F' ?
# Be exact to one second to ensure saved original files
# of directly subsequent 'rear WORKFLOW' are saved with different filenames
# that could help to avoid confusion when debugging issues later:
DATE=$( date +%Y%m%d%H%M%S )

# Each file will be only saved once by save_original_file()
# and all subsequent save_original_file() for the same file do nothing
# because each saved file is remembered in the SAVED_ORIGINAL_FILES array:
SAVED_ORIGINAL_FILES=()
SAVED_ORIGINAL_FILE_SUFFIX="orig"

# Save the original content of the file $1 to $1.$DATE.$2.orig
# or to $1.$DATE.$WORKFLOW.$MASTER_PID.orig when no $2 is specified:
save_original_file() {
    local filename="$1"
    test -r "$filename" || return 1
    IsInArray "$filename" "${SAVED_ORIGINAL_FILES[@]}" && return 0
    local extension="$2"
    test "$extension" || extension=$WORKFLOW.$MASTER_PID
    local saved_original_file="$filename.$DATE.$extension.$SAVED_ORIGINAL_FILE_SUFFIX"
    cp -ar $filename $saved_original_file && SAVED_ORIGINAL_FILES=( "${SAVED_ORIGINAL_FILES[@]}" "$filename" )
}

# Restore the saved original content of the original file named $1
# that was saved as $1.$DATE.$2.orig or $1.$DATE.$WORKFLOW.$MASTER_PID.orig
restore_original_file() {
    local filename="$1"
    local extension="$2"
    test "$extension" || extension=$WORKFLOW.$MASTER_PID
    local saved_original_file="$filename.$DATE.$extension.$SAVED_ORIGINAL_FILE_SUFFIX"
    test -r "$saved_original_file" || return 1
    cp -ar $saved_original_file $filename
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
    if type -t create_$type >/dev/null ; then
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
    Log "Restoring saved original $LAYOUT_FILE"
    restore_original_file "$LAYOUT_FILE"
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
                # When a LV is a Thin, then we need to create the Thin Pool first
                pool=$(echo "$remainder" | egrep -ow "thinpool:\\S+" | cut -d ":" -f 2)

                # Vgs and Lvs containing - in their name have a double dash in DM
                dm_vgrp=${vgrp//-/--}
                dm_lvol=${lvol//-/--}
                dm_pool=${pool//-/--}

                dm_prefix="/dev/mapper/${dm_vgrp#/dev/}"
                add_dependency "$dm_prefix-$dm_lvol" "$vgrp"
                [ -z "$pool" ] || add_dependency "$dm_prefix-$dm_lvol" "$dm_prefix-$dm_pool"
                add_component "$dm_prefix-$dm_lvol" "lvmvol"
                ;;
            raid)
                name=$(echo "$remainder" | cut -d " " -f "1")
                disks=( $(echo "$remainder" | sed -r "s/.*devices=([^ ]+).*/\1/" | tr ',' ' ') )
                for disk in "${disks[@]}" ; do
                    add_dependency "$name" "$disk"
                done
                add_component "$name" "raid"
                ;;
            fs|btrfsmountedsubvol)
                dev=$(echo "$remainder" | cut -d " " -f "1")
                mp=$(echo "$remainder" | cut -d " " -f "2")
                add_dependency "$type:$mp" "$dev"
                add_component "$type:$mp" "$type"

                # find dependencies on other filesystems
                while read dep_type bd dep_mp junk; do
                    if [ "$dep_mp" != "/" ] ; then
                        # make sure we only match complete paths
                        # e.g. not /data as a parent of /data1
                        temp_dep_mp="$dep_mp/"
                    else
                        temp_dep_mp="$dep_mp"
                    fi

                    if [ "${mp#$temp_dep_mp}" != "${mp}" ] && [ "$mp" != "$dep_mp" ]; then
                        add_dependency "$type:$mp" "$dep_type:$dep_mp"
                    fi
                done < <(awk '$1 ~ /^fs|btrfsmountedsubvol$/ { print; }' $LAYOUT_FILE)
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
                dev=$(echo "$remainder" | cut -d " " -f "2")
                add_dependency "$name" "$dev"
                add_component "$name" "crypt"
                ;;
            multipath)
                name=$(echo "$remainder" | cut -d " " -f "1")
                disks=$(echo "$remainder" | cut -d " " -f "3" | tr "," " ")

                add_component "$name" "multipath"

                for disk in $disks ; do
                    add_dependency "$name" "$disk"
                done
                ;;
            opaldisk)
                dev=$(echo "$remainder" | cut -d " " -f "1")
                add_component "opaldisk:$dev" "opaldisk"
                add_dependency "$dev" "opaldisk:$dev"
                ;;
        esac
    done < $LAYOUT_FILE
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
    [ $number -gt 0 ] 2>/dev/null
    StopIfError "Partition number '$number' of partition $partition is not a valid number."

    # Catch if $number is too big, report it as a bug
    (( $number <= 128 ))
    StopIfError "Partition $partition is numbered '$number'. More than 128 partitions is not supported."

    echo $number
}
# Returns partition start block or 'unknown'
# sda/sda1 or
# dm-XX
get_partition_start() {
    local disk_name=$1
    local start_block start

    local block_size=$(get_block_size ${disk_name%/*})

    if [[ -r /sys/block/$disk_name/start ]] ; then
        start_block=$(< $path/start)
    elif [[ $disk_name =~ ^dm- ]]; then
        # /dev/mapper/mpath4-part1
        local devname=$(get_device_name $disk_name)
        devname=${devname#/dev/mapper/}

        # 0 536846303 linear 253:7 536895488
        read junk junk junk junk start_block < <( dmsetup table ${devname} 2>/dev/null )
    fi
    if [[ -z $start_block ]]; then
        Log "Could not determine start of partition $partition_name."
        start="unknown"
    else
        start=$(( start_block * block_size ))
    fi

    echo $start
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
    local dev_number=$(dmsetup info -c --noheadings -o major,minor ${name##*/} 2>/dev/null )
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

    contains_visible_char "$name" || BugError "Empty string passed to get_device_name"

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
                mapper_number=$(dmsetup info -c --noheadings -o major,minor ${device#/dev/mapper/} 2>/dev/null )
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
# 220_lvm_layout.sh uses get_device_mapping to translate lvmdev better
### ciss-3600508b1001fffffa004f7b3f209000b-part2 -> cciss/c0d0p2
# see issue #305
get_device_mapping() {
    if [[ ! -s "${VAR_DIR}/recovery/diskbyid_mappings" ]]; then
        echo $1
    else
        local name=${1##*/}      # /dev/disk/by-id/scsi-xxxx -> scsi-xxx
        local disk_name=$(grep -w "^${name}" ${VAR_DIR}/recovery/diskbyid_mappings | awk '{print $2}')
        if [[ -z "$disk_name" ]]; then
            echo $1
        else
            echo "$disk_name"
        fi
    fi
}

# Get the size in bytes of a disk/partition.
# For partitions, use "sda/sda1" as argument.
get_disk_size() {
    local disk_name=$1

    local block_size=$(get_block_size ${disk_name%/*})

    retry_command test -r /sys/block/$disk_name/size || Error "Could not determine size of disk $disk_name"

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

# Get the LABEL of a device.
# Device is something like /dev/sda1.
blkid_label_of_device() {
    local device=$1
    local label=""
    for LINE in $(blkid $device  2>/dev/null)
    do
        label=$( echo "$LINE" | grep "^LABEL=" | cut -d= -f2 | sed -e 's/"//g' | sed -e 's/ /\\\\b/g')  # replace all " " with "\\b"
        [[ ! -z "$label" ]] && break
    done
    echo "$label"
}

# Returns 1 if the device is an LVM physical volume
# Returns 0 otherwise or if the device doesn't exists
is_disk_a_pv() {
    disk=$1
    if grep -q "^lvmdev .* ${disk} " $LAYOUT_FILE ; then
        return 0
    else
        return 1
    fi
}

function is_multipath_path {
    [ "$1" ] && type multipath &>/dev/null && multipath -c /dev/$1 &>/dev/null
}

# retry_command () is binded with REAR_SLEEP_DELAY and REAR_MAX_RETRIES.
# This function will do maximum of REAR_MAX_RETRIES command execution
# and will sleep REAR_SLEEP_DELAY after each unsuccessful command execution.
# It outputs command stdout if succeeded or returns 1 on failure.
retry_command ()
{
    local retry=0

    until command_stdout=$(eval "$@"); do
        sleep $REAR_SLEEP_DELAY

        let retry++

        if (( retry >= REAR_MAX_RETRIES )) ; then
            Log "retry_command '$*' failed"
            return 1
        fi
    done
    # Have no additional trailing newline for the command stdout:
    echo -n "$command_stdout"
}

# UdevSymlinkName (device) return all the udev symlink created by udev to the device.
# example:
# UdevSymlinkName /dev/sda1
#  /dev/disk/by-id/ata-SAMSUNG_MZNLN512HMJP-000L7_S2XANX0H603095-part1 /dev/disk/by-id/wwn-0x5002538d00000000-part1 /dev/disk/by-label/boot /dev/disk/by-partuuid/7d51513d-01 /dev/disk/by-path/pci-0000:00:17.0-ata-1-part1 /dev/disk/by-uuid/b3c0fd92-28cf-4591-b4f5-1a32913f4319
function UdevSymlinkName() {
    unset device
    device="$1"

    # Exit with Error if no argument is provided to UdevSymlinkName
    contains_visible_char "$device" || Error "Empty string passed to UdevSymlinkName()"

    # udevinfo is deprecated by udevadm (SLES 10 still uses udevinfo)
    type -p udevinfo >/dev/null && UdevSymlinkName="udevinfo -r / -q symlink -n"
    type -p udevadm >/dev/null && UdevSymlinkName="udevadm info --root --query=symlink --name"

    if test -z "$UdevSymlinkName" ; then
        LogPrint "Could not find udevinfo nor udevadm. UdevSymlinkName($device) failed."
        return 1
    fi

    $UdevSymlinkName $device
}

# UdevQueryName (device) return all the real device name from udev symlink.
# example:
# UdevQueryName /dev/disk/by-id/wwn-0x5002538d00000000-part1
#  sda1
# WARNING: like udevadm, this function return device name (sda1) not absolute PATH (/dev/sda1)
function UdevQueryName() {
    unset device_link
    device_link="$1"

    # Exit with Error if no argument is provided to UdevSymlinkName
    contains_visible_char "$device_link" || Error "Empty string passed to UdevQueryName()"

    # be careful udevinfo is old, now we have udevadm
    # udevinfo -r -q name -n /dev/disk/by-id/scsi-360060e8015268c000001268c000065c0-part4
    # udevadm info --query=name --name /dev/disk/by-id/dm-name-vg_fedora-lv_root
    type -p udevinfo >/dev/null && UdevQueryName="udevinfo -r -q name -n"
    type -p udevadm >/dev/null && UdevQueryName="udevadm info --query=name --name"

    if test -z "$UdevQueryName" ; then
        LogPrint "Could not find udevinfo nor udevadm. UdevQueryName($device_link) failed."
        return 1
    fi

    $UdevQueryName $device_link
}

# Guess the part device name from a device, based on the OS distro Level.
function get_part_device_name_format() {
    if [ -z "$1" ] ; then
        BugError "get_part_device_name_format function called without argument (device)"
    else
        device_name="$1"
    fi

    part_name="$device_name"

    case "$device_name" in
        (*mmcblk[0-9]*|*nvme[0-9]*n[1-9]*|*rd[/!]c[0-9]*d[0-9]*|*cciss[/!]c[0-9]*d[0-9]*|*ida[/!]c[0-9]*d[0-9]*|*amiraid[/!]ar[0-9]*|*emd[/!][0-9]*|*ataraid[/!]d[0-9]*|*carmel[/!][0-9]*)
            part_name="${device_name}p" # append p between main device and partitions
            ;;
        (*mapper[/!]*)
            # Every Linux distribution / version has their own rule to name the multipthed partion device.
            #
            # Suse:
            #     Version <12 : always <device>_part<part_num> (same with/without user_friendly_names)
            #     Version >=12 : always <device>-part<part_num> (same with/without user_friendly_names)
            #     Question still open for sles10 ...
            # RedHat:
            #     Version <7 : always <device>p<part_num> (same with/without user_friendly_names)
            #     Version >=7 : if user_friendly_names (default) <device><part_num> else <device>p<part_num>
            # Debian:
            #     if user_firendly_names (default) <device>-part<part_num>
            #     if NOT user_firendly_names <device>p<part_num>
            #

            # First we need to know if user_friendly_names is activated (for Fedora/RedHat and Debian/ubuntu)
            if multipathd ; then
                # check if multipath if using the "user_friendly_names" by default in the current configuration.
                user_friendly_names=$(echo "show config" | multipathd -k | awk '/user_friendly_names/ { gsub("\"","") ; print $2 }' | head -n 1 )
            fi

            case $OS_MASTER_VENDOR in

                (SUSE)
                    # No need to check if user_friendly_names is activated or not as Suse always apply the same naming convention.

                    # SUSE Linux SLE12 put a "-part" between [mpath device name] and [part number].
                    # For example /dev/mapper/3600507680c82004cf8000000000000d8-part1.
                    # But SLES11 uses a "_part" instead. (Let's assume it is the same for SLES10 )
                    if (( $OS_MASTER_VERSION < 12 )) ; then
                        # For SUSE before version 12
                        part_name="${device_name}_part" # append _part between main device and partitions
                    else
                        # For SUSE 12 or above
                        part_name="${device_name}-part" # append -part between main device and partitions
                    fi
                ;;

                (Fedora)
                    if is_false "$user_friendly_names" ; then
                        # RHEL 7 and above seems to named partitions on multipathed devices with
                        # [mpath device UUID/WWID] + p + [part number] when "user_friendly_names"
                        # option is FALSE.
                        # For example: /dev/mapper/3600507680c82004cf8000000000000d8p1
                        part_name="${device_name}p" # append p between main device and partitions
                    else
                        # RHEL 7 and above seems to named partitions on multipathed devices with
                        # [mpath device name] + [part number] like standard disk when "user_friendly_names"
                        # option is used (default).
                        # For example: /dev/mapper/mpatha1
                        # But the scheme in RHEL 6 need a "p" between [mpath device name] and [part number].
                        # For exemple: /dev/mapper/mpathap1
                        if (( $OS_MASTER_VERSION < 7 )) ; then
                            part_name="${device_name}p" # append p between main device and partitions
                        else
                            part_name="${device_name}"
                        fi
                    fi
                ;;

                (Debian)
                    if is_false "$user_friendly_names" ; then
                        # Exceptional case for Debian/ubuntu
                        # When user_friendly_names is disable, debian based system will name partition
                        # [mpath device UUID/WWID] + p + [part number]
                        part_name="${device_name}p"
                    else
                        # Default case (user_friendly_name enable)
                        # Ubuntu 16.04 (need to check for other version) named muiltipathed partitions with
                        # [mpath device name] + "-part" + [part number]
                        # for example : /dev/mapper/mpatha-part1
                        part_name="${device_name}-part" # append -part between main device and partitions
                    fi
                ;;

                (*)
                    # For all the other case, use /dev/mapper/mpatha1 type
                    part_name="$device_name"
                ;;
            esac
        ;;
    esac

    echo "$part_name"
}

# The is_completely_identical_layout_mapping function checks
# if there is a completely identical mapping in the mapping file
# (usually $MAPPING_FILE is /var/lib/rear/layout/disk_mappings)
# which is used to avoid that files (in particular restored files)
# may get needlessly touched and modified for identical mappings
# see https://github.com/rear/rear/issues/1847
function is_completely_identical_layout_mapping() {
    # MAPPING_FILE is set in layout/prepare/default/300_map_disks.sh
    # only if MIGRATION_MODE is true.
    # When $MAPPING_FILE is empty the below command
    #   grep -v '^#' "$MAPPING_FILE"
    # would hang up endlessly without user notification
    # because that command would become
    #   grep -v '^#'
    # which reads from stdin (i.e. from the user's keyboard).
    # A non-existent mapping file is considered to be a completely identical mapping
    # (i.e. 'no mapping' means 'do not change anything' which is the identity map).
    test -f "$MAPPING_FILE" || return 0
    # Only non-commented and syntactically valid lines in the mapping file count
    # so that also an empty mapping file or when there is not at least one valid mapping
    # are considered to be completely identical mappings
    # (i.e. 'no valid mapping' means 'do not change anything' which is the identity map):
    while read source target junk ; do
        # Skip lines that have wrong syntax:
        test "$source" -a "$target" || continue
        test "$source" != "$target" && return 1
    done < <( grep -v '^#' "$MAPPING_FILE" )
    Log "Completely identical layout mapping in $MAPPING_FILE"
    return 0
}

# apply_layout_mappings function migrate disk device references
# from an old system and replace them with new ones (from current system).
# The relationship between OLD and NEW device is provided by the mapping file
# (usually $MAPPING_FILE is /var/lib/rear/layout/disk_mappings).
function apply_layout_mappings() {
    local file_to_migrate="$1"

    # Exit if MIGRATION_MODE is not true.
    is_true "$MIGRATION_MODE" || return 0

    # apply_layout_mappings needs one argument:
    test "$file_to_migrate" || BugError "apply_layout_mappings function called without argument (file_to_migrate)."

    # Only apply layout mapping on non-empty file:
    test -s "$file_to_migrate" || return 0

    # Do not apply layout mappings when there is a completely identical mapping in the mapping file.
    # This test is run for each call of the apply_layout_mappings function because
    # in MIGRATION_MODE there are several user dialogs during "rear recover" where
    # the user can run the ReaR shell and edit the mapping file as he likes:
    is_completely_identical_layout_mapping && return 0

    # Generate unique words (where unique means that those generated words cannot already exist in file_to_migrate)
    # as replacement placeholders to correctly handle circular replacements e.g. for "sda -> sdb and sdb -> sda"
    # in the mapping file those generated unique words would be _REAR0_ for sda and _REAR1_ for sdb.
    # The replacement strategy is:
    # Step 0:
    # For each original device in the mapping file generate a unique word (the "replacement").
    # Step 1:
    # In file_to_migrate temporarily replace all original devices with their matching unique word.
    # E.g. "disk sda and disk sdb" would become "disk _REAR0_ and disk _REAR1_" temporarily in file_to_migrate.
    # Step 2:
    # In file_to_migrate replace all unique replacement words with the matching target device of the source device.
    # E.g. for "sda -> sdb and sdb -> sda" in the mapping file and the unique words _REAR0_ for sda and _REAR1_ for sdb
    # "disk _REAR0_ and disk _REAR1_" would become "disk sdb and disk sda" in the final file_to_migrate
    # so that the circular replacement "sda -> sdb and sdb -> sda" is done in file_to_migrate.
    # Step 3:
    # In file_to_migrate verify that there are none of those temporary replacement words from step 1 left
    # to ensure the replacement was done correctly and completely.

    # Replacement_file initialization.
    replacement_file="$TMP_DIR/replacement_file"
    : > "$replacement_file"

    function add_replacement() {
        # We temporarily map all devices in the mapping to new names _REAR[0-9]+_
        echo "$1 _REAR${replacement_count}_" >> "$replacement_file"
        let replacement_count++
    }

    function has_replacement() {
        grep -q "^$1 " "$replacement_file"
    }

    function get_replacement() {
        local item replacement junk
        read item replacement junk < <( grep "^$1 " $replacement_file )
        test "$replacement" && echo "$replacement" || return 1
    }

    # Step 0:
    # For each original device in the mapping file generate a unique word (the "replacement").
    # E.g. when the mapping file content is
    #   /dev/sda /dev/sdb
    #   /dev/sdb /dev/sda
    #   /dev/sdd /dev/sdc
    # the replacement file will contain
    #   /dev/sda _REAR0_
    #   /dev/sdb _REAR1_
    #   /dev/sdd _REAR2_
    #   /dev/sdc _REAR3_
    replacement_count=0
    while read source target junk ; do
        # Skip lines that have wrong syntax:
        test "$source" -a "$target" || continue
        has_replacement "$source" || add_replacement "$source"
        has_replacement "$target" || add_replacement "$target"
    done < <( grep -v '^#' "$MAPPING_FILE" )

    # Step 1:
    # Replace all original devices with their replacements.
    # E.g. when the file_to_migrate content is
    #   disk /dev/sda
    #   disk /dev/sdb
    #   disk /dev/sdc
    #   disk /dev/sdd
    # it will get temporarily replaced (with the replacement file content in step 0 above) by
    #   disk _REAR0_
    #   disk _REAR1_
    #   disk _REAR3_
    #   disk _REAR2_
    while read original replacement junk ; do
        # Skip lines that have wrong syntax:
        test "$original" -a "$replacement" || continue
        # Replace partitions with unique replacement PATTERN (we normalize cciss/c0d0p1 to _REAR5_1)
        # Due to multipath partion naming complexity, all known partition naming type (mpatha1,mpathap1,mpatha-part1,mpatha_part1) will be replaced by _REAR"X"_1
        sed -i -r "\|$original|s|$original(p)*([-_]part)*([0-9]+)|$replacement\3|g" "$file_to_migrate"
        # Replace whole devices
        # Note that / is a word boundary, so is matched by \<, hence the extra /
        sed -i -r "\|$original|s|/\<${original#/}\>|${replacement}|g" "$file_to_migrate"
    done < "$replacement_file"

    # Step 2:
    # Replace all unique replacement words with the matching target device of the source device in the mapping file.
    # E.g. when the file_to_migrate content was in step 1 above temporarily changed to
    #   disk _REAR0_
    #   disk _REAR1_
    #   disk _REAR3_
    #   disk _REAR2_
    # it will now get finally replaced (with the replacement file and mapping file contents in step 0 above) by
    #   disk /dev/sdb
    #   disk /dev/sda
    #   disk _REAR3_
    #   disk /dev/sdc
    # where the temporary replacement "disk _REAR3_" from step 1 above is left because
    # there is (erroneously) no mapping for /dev/sdc (as source device) in the mapping file (in step 0 above).
    while read source target junk ; do
        # Skip lines that have wrong syntax:
        test "$source" -a "$target" || continue
        # Skip when there is no replacement:
        replacement=$( get_replacement "$source" ) || continue
        # Replace whole device:
        sed -i -r "\|$replacement|s|$replacement\>|$target|g" "$file_to_migrate"
        # Replace partitions:
        target=$( get_part_device_name_format "$target" )
        sed -i -r "\|$replacement|s|$replacement([0-9]+)|$target\1|g" "$file_to_migrate"
    done < <( grep -v '^#' "$MAPPING_FILE" )

    # Step 3:
    # Verify that there are none of those temporary replacement words from step 1 left in file_to_migrate
    # to ensure the replacement was done correctly and completely (cf. the above example where '_REAR3_' is left).
    apply_layout_mappings_succeeded="yes"
    while read original replacement junk ; do
        # Skip lines that have wrong syntax:
        test "$original" -a "$replacement" || continue
        if grep -q "$replacement" "$file_to_migrate" ; then
            apply_layout_mappings_succeeded="no"
            LogPrintError "Failed to apply layout mappings to $file_to_migrate for $original (probably no mapping for $original in $MAPPING_FILE)"
        fi
    done < "$replacement_file"
    # It is the responsibility of the caller of this apply_layout_mappings function what to do when it failed
    # (e.g. error out, retry, show a user dialog, or whatever is appropriate in the caller's environment):
    is_true $apply_layout_mappings_succeeded && return 0 || return 1
}

# vim: set et ts=4 sw=4:
