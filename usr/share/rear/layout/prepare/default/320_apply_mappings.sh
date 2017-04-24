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
        *mmcblk[0-9]*|*nvme[0-9]*n[1-9]*|*rd[/!]c[0-9]*d[0-9]*|*cciss[/!]c[0-9]*d[0-9]*|*ida[/!]c[0-9]*d[0-9]*|*amiraid[/!]ar[0-9]*|*emd[/!][0-9]*|*ataraid[/!]d[0-9]*|*carmel[/!][0-9]*)
            part_base="${original}p" # append p between main device and partitions
            ;;
        *mapper[/!]*)
            case $OS_VENDOR in
                SUSE_LINUX)
                # SUSE Linux SLE12 put a "-part" between [mpath device name] and [part number].
                # For example /dev/mapper/3600507680c82004cf8000000000000d8-part1.
                # But SLES11 uses a "_part" instead. (Let's assume it is the same for SLES10 )
                if (( $OS_VERSION < 12 )) ; then
                    # For SUSE before version 12
                    part_base="${original}_part" # append _part between main device and partitions
                else
                    # For SUSE 12 or above
                    part_base="${original}-part" # append -part between main device and partitions
                fi
                ;;
                RedHatEnterpriseServer)
                    # RHEL 7 and above seems to named partitions on multipathed devices with
                    # [mpath device name] + [part number] like standard disk.
                    # For example: /dev/mapper/mpatha1

                    # But the scheme in RHEL 6 need a "p" between [mpath device name] and [part number].
                    # For exemple: /dev/mapper/mpathap1
                    if (( $OS_VERSION < 7 )) ; then
                        part_base="${original}p" # append p between main device and partitions
                    fi
                ;;
                Ubuntu)
                    # Ubuntu 16.04 (need to check for other version) named muiltipathed partitions with
                    # [mapth device name] + "-part" + [part number]
                    # for example : /dev/mapper/mpatha-part1
                    part_base="${original}-part" # append -part between main device and partitions
                ;;

            esac
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
        *mmcblk[0-9]|*nvme[0-9]*n[1-9]|*rd[/!]c[0-9]d[0-9]|*cciss[/!]c[0-9]d[0-9]|*ida[/!]c[0-9]d[0-9]|*amiraid[/!]ar[0-9]|*emd[/!][0-9]|*ataraid[/!]d[0-9]|*carmel[/!][0-9])
            target="${target}p" # append p between main device and partitions
            ;;
        *mapper[/!]*)
            case $OS_VENDOR in
                SUSE_LINUX)
                    # SUSE Linux SLE12 put a "-part" between [mpath device name] and [part number].
                    # For example /dev/mapper/3600507680c82004cf8000000000000d8-part1.
                    # But SLES11 uses a "_part" instead. (Let's assume it is the same for SLES10 )
                    if (( $OS_VERSION < 12 )) ; then
                        # For SUSE before version 12
                        target="${target}_part" # append _part between main device and partitions
                    else
                        # For SUSE 12 or above
                        target="${target}-part" # append -part between main device and partitions
                    fi
                ;;
                RedHatEnterpriseServer)
                    # RHEL 7 and above seems to named partitions on multipathed devices with
                    # [mpath device name] + [part number] like standard disk.
                    # For example: /dev/mapper/mpatha1

                    # But the scheme in RHEL 6 need a "p" between [mpath device name] and [part number].
                    # For exemple: /dev/mapper/mpathap1
                    if (( $OS_VERSION < 7 )) ; then
                        target="${target}p" # append p between main device and partitions
                    fi
                ;;
                Ubuntu)
                    # Ubuntu 16.04 (need to check for other version) named muiltipathed partitions with
                    # [mapth device name] + "-part" + [part number]
                    # for example : /dev/mapper/mpatha-part1
                    target="${target}-part" # append -part between main device and partitions
                ;;
            esac
        ;;
    esac
    sed -i -r "\|$replacement|s|$replacement([0-9]+)|$target\1|g" "$LAYOUT_FILE"
done < "$MAPPING_FILE"
