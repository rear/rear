# Map source disks to target disks

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

MAPPING_FILE=$VAR_DIR/layout/disk_mappings
: > $MAPPING_FILE

# Add a mapping from <source> to <target>
# Source/Target should be "like sda" "cciss/c1d0"
add_mapping() {
    echo "$1 $2" >> $MAPPING_FILE
}

# Return 0 if a mapping for <$1> exists
mapping_exists() {
    if grep -q "^$1 " $MAPPING_FILE ; then
        return 0
    else
        return 1
    fi
}

# Return 0 if <$1> is used in a mapping.
reverse_mapping_exists() {
    if grep -q " $1$" $MAPPING_FILE ; then
        return 0
    else
        return 1
    fi
}

if [ -e /etc/rear/mappings/disk_devices ] ; then
    cp /etc/rear/mappings/disk_devices $MAPPING_FILE
fi

# Automap old disks
while read disk dev size junk ; do
    if mapping_exists "$dev" ; then
        continue
    fi
    
    for path in $(ls -d /sys/block/* 2>/dev/null) ; do
        if [ ! -r $path/size ] || [ ! -d $path/queue ] ; then
            continue
        fi
        newsize=$(cat $path/size)
        
        if [ "$size" -eq "$newsize" ] && ! reverse_mapping_exists "/dev/$(get_device_name $path)"; then
            add_mapping "$dev" "/dev/$(get_device_name $path)"
            break
        fi
    done
done < <(grep "^disk " $LAYOUT_FILE)

# For every unmapped disk in the source system
while read -u 3 disk dev size junk ; do
    if mapping_exists "$dev" ; then
        continue
    fi
    # Allow the user to select from the set of unmapped disks
    possible_targets=()
    for path in $(ls -d /sys/block/* 2>/dev/null) ; do
        if ! reverse_mapping_exists $(get_device_name $path) && [ -d $path/queue ] ; then
            possible_targets=("${possible_targets[@]}" "$(get_device_name $path)")
        fi
    done
    
    LogPrint "Disk ${dev#/dev/} does not exist in the target system. Please choose the appropriate replacement."
    select choice in "${possible_targets[@]}" "Do not map disk." ; do
        n=( $REPLY ) # trim blanks from reply
        let n-- # because bash arrays count from 0
        if [ "$n" = "${#possible_targets[@]}" ] || [ "$n" -lt 0 ] || [ "$n" -ge "${#possible_targets[@]}" ] ; then
            LogPrint "Disk ${dev#/dev/} not automatically replaced."
        else
            LogPrint "Disk $choice chosen as replacement for ${dev#/dev/}."
            add_mapping "$dev" "/dev/$choice"
        fi
        break
    done 2>&1 # to get the prompt, otherwise it would go to the logfile
done 3< <(grep "^disk " $LAYOUT_FILE)

# Apply the mapping in the layout file

# We temporarily map all devices in the mapping to new names _REAR[0-9]+_
replaced_count=0
replacement_file=$TMP_DIR/replacement_file
: > $replacement_file

add_replacement() {
    echo "$1 _REAR${replaced_count}_" >> $replacement_file
    let replaced_count++
}

has_replacement() {
    if grep -q "^$1 " $replacement_file ; then
        return 0
    else
        return 1
    fi
}

get_replacement() {
    read item replacement junk < <(grep "^$1 " $replacement_file)
    echo "$replacement"
}

# Generate replacements
while read source target junk ; do
    if ! has_replacement "$source" ; then
        add_replacement "$source"
    fi
    
    if ! has_replacement "$target" ; then
        add_replacement "$target"
    fi
done < $MAPPING_FILE

LogPrint "This is the disk mapping table:"
cat $MAPPING_FILE

# Replace all originals with their replacements
while read original replacement junk ; do
    # Replace partitions (we normalize cciss/c0d0p1 to _REAR5_1)
    sed -i -r "\|$original|s|${original}p*([0-9]+)|$replacement\1|g" $LAYOUT_FILE
    # Replace whole devices
    sed -i -r "\|$original|s|$original|$replacement|g" $LAYOUT_FILE
done < $replacement_file

# Replace all replacements with their target
while read source target junk ; do
    replacement=$(get_replacement "$source")
    # Replace whole device
    sed -i -r "\|$replacement|s|$replacement([^0-9])|$target\1|g" $LAYOUT_FILE
    # Replace partitions
    case "$target" in
        *rd[/!]c[0-9]d[0-9]|*cciss[/!]c[0-9]d[0-9]|*ida[/!]c[0-9]d[0-9]|*amiraid[/!]ar[0-9]|*emd[/!][0-9]|*ataraid[/!]d[0-9]|*carmel[/!][0-9])
            target="${target}p" # append p between main device and partitions
            ;;
    esac
    sed -i -r "\|$replacement|s|$replacement([0-9]+)|$target\1|g" $LAYOUT_FILE
done < $MAPPING_FILE
