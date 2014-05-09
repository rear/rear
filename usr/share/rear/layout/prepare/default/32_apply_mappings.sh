# Apply the mapping in the layout file.

if [ -z "$MIGRATION_MODE" ] ; then
    return 0
fi

# We temporarily map all devices in the mapping to new names _REAR[0-9]+_
replaced_count=0
replacement_file="$TMP_DIR/replacement_file"
: > "$replacement_file"

add_replacement() {
    echo "$1 _REAR${replaced_count}_" >> "$replacement_file"
    let replaced_count++
}

has_replacement() {
    if grep -q "^$1 " "$replacement_file" ; then
        return 0
    else
        return 1
    fi
}

get_replacement() {
    local item replacement junk
    read item replacement junk < <(grep "^$1 " $replacement_file)
    echo "$replacement"
}

# Generate replacements.
while read source target junk ; do
    if ! has_replacement "$source" ; then
        add_replacement "$source"
    fi

    if ! has_replacement "$target" ; then
        add_replacement "$target"
    fi
done < "$MAPPING_FILE"

# Replace all originals with their replacements.
while read original replacement junk ; do
    # Replace partitions (we normalize cciss/c0d0p1 to _REAR5_1)
    part_base="$original"
    case "$original" in
        *rd[/!]c[0-9]*d[0-9]*|*cciss[/!]c[0-9]*d[0-9]*|*ida[/!]c[0-9]*d[0-9]*|*amiraid[/!]ar[0-9]*|*emd[/!][0-9]*|*ataraid[/!]d[0-9]*|*carmel[/!][0-9]*)
            part_base="${original}p" # append p between main device and partitions
            ;;
    esac
    sed -i -r "\|$original|s|${part_base}([0-9]+)|$replacement\1|g" "$LAYOUT_FILE"
    # Replace whole devices
    ### note that / is a word boundary, so is matched by \<, hence the extra /
    sed -i -r "\|$original|s|/\<${original#/}\>|${replacement}|g" "$LAYOUT_FILE"
done < "$replacement_file"

# Replace all replacements with their target.
while read source target junk ; do
    replacement=$(get_replacement "$source")
    # Replace whole device
    sed -i -r "\|$replacement|s|$replacement\>|$target|g" "$LAYOUT_FILE"
    # Replace partitions
    case "$target" in
        *rd[/!]c[0-9]d[0-9]|*cciss[/!]c[0-9]d[0-9]|*ida[/!]c[0-9]d[0-9]|*amiraid[/!]ar[0-9]|*emd[/!][0-9]|*ataraid[/!]d[0-9]|*carmel[/!][0-9])
            target="${target}p" # append p between main device and partitions
            ;;
    esac
    sed -i -r "\|$replacement|s|$replacement([0-9]+)|$target\1|g" "$LAYOUT_FILE"
done < "$MAPPING_FILE"
