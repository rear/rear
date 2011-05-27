# Generate dependencies between disks as found in $LAYOUT_FILE
# This will be written to $LAYOUT_DEPS
# Also generate a list of disks to be restored in $LAYOUT_TODO

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

while read type remainder ; do
    case $type in
        disk)
            name=$(echo "$remainder" | cut -d " " -f "1")
            add_component "$name" "disk"
            ;;
        part)
            # disk is the first field of the remainder
            disk=$(echo "$remainder" | cut -d " " -f "1")
            name=$(echo "$remainder" | cut -d " " -f "5")
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
            name=$(echo "$remainder" | cut -d " " -f "2")
            
            # Volume groups containing - in their name have a double dash in DM
            dm_vgrp=${vgrp/-/--}
            
            add_dependency "/dev/mapper/${dm_vgrp#/dev/}-$name" "$vgrp"
            add_component "/dev/mapper/${dm_vgrp#/dev/}-$name" "lvmvol"
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
            
            for disk in $disks ; do
                add_dependency "$name" "$disk"
                add_component "$name" "multipath"
            done
            ;;
    esac
done < <(cat $LAYOUT_FILE)
