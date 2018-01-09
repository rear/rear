# Remove the excluded components from the disklayout file.
# Excluded components are marked as DONE in the disktodo file.

if ! [ -s "$LAYOUT_TODO" ] ; then
    return 0
fi

# Component in position 2.
remove_component() {
    sed -i "s|^$1 $2 |\#$1 $2 |" "$LAYOUT_FILE"
}

# Component in position 3.
remove_second_component() {
    sed -i -r "s|^$1 ([^ ]+) $2 |\#$1 \1 $2 |" "$LAYOUT_FILE"
}

# Remove lines in the LAYOUT_FILE.
while read status name type junk ; do
    case "$type" in
        part)
            ### find the immediate parent
            name=$(grep "^$name " "$LAYOUT_DEPS" | cut -d " " -f 2)
            remove_component "$type" "$name"
            ;;
        lvmvol)
            name=${name#/dev/mapper/}
            ### split between vg and lv is single dash
            ### Device mapper doubles dashes in vg and lv
            vg=$(sed "s/\([^-]\)-[^-].*/\1/;s/--/-/g" <<< "$name")
            lv=$(sed "s/.*[^-]-\([^-]\)/\1/;s/--/-/g" <<< "$name")

            sed -i -r "s|^($type /dev/$vg $lv )|\#\1|" "$LAYOUT_FILE"
            ;;
        fs|btrfsmountedsubvol|swap|lvmdev|opaldisk)
            name=${name#$type:}
            remove_second_component "$type" "$name"
            ;;
        *)
            remove_component "$type" "$name"
            ;;
    esac
done < <(grep "^done" "$LAYOUT_TODO")

# Remove all LVM PVs of excluded VGs.
while read status name junk ; do
    remove_component "lvmdev" "$name"
done < <(grep -E "^done [^ ]+ lvmgrp" "$LAYOUT_TODO")
