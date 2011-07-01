# Remove the excluded components from the disklayout file.
# Excluded components are marked as DONE in the disktodo file.

if ! [ -s "$LAYOUT_TODO" ] ; then
    return 0
fi

# Component in position 2
remove_component() {
    sed -i "s|^$1 $2 |\# $1 $2 |" $LAYOUT_FILE
}

# Component in position 3
remove_second_component() {
    sed -i -r "s|^$1 ([^ ]+) $2 |\# $1 \1 $2 |" $LAYOUT_FILE
}

# Remove lines in the LAYOUT_FILE
while read done name type junk ; do
    case $type in 
        part)
            name=$( echo "$name" | sed -r 's/(.*)[0-9]$/\1/')
            if [ "${name/cciss/}" != "$name" ] ; then
                name=${name%p}
            fi
            remove_component $type $name
            ;;
        lvmdev)
            name=${name#pv:}
            remove_second_component $type $name
            ;;
        lvmvol)
            name=${name##/dev/mapper/*-}
            remove_second_component $type $name
            ;;
        fs)
            name=${name#fs:}
            remove_second_component $type $name
            ;;
        swap)
            name=${name#swap:}
            remove_component $type $name
            ;;
        *)
            remove_component $type $name
            ;;
    esac
done < <(grep "^done" $LAYOUT_TODO)

# Remove all LVM PVs of excluded VGs
while read status name junk ; do
    remove_component "lvmdev" "$name"
done < <(grep -E "^done [^ ]+ lvmgrp"  $LAYOUT_TODO)
