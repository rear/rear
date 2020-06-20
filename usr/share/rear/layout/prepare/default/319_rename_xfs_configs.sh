# Cleanup directory which hold XFS configuration file for `rear recover'.
# This will avoid possible mess in LAYOUT_XFS_OPT_DIR_RESTORE if `rear recover'
# would be launched multiple times, where user will choose different disk
# mapping each time.
# Removing and creating LAYOUT_XFS_OPT_DIR_RESTORE will ensure that ReaR will
# have only current files available during current session.
rm -rf "$LAYOUT_XFS_OPT_DIR_RESTORE"
mkdir -p "$LAYOUT_XFS_OPT_DIR_RESTORE"

local excluded_configs=()

# Read $MAPPING_FILE (disk_mappings) to discover final disk mapping.
# Once mapping is known, configuration files can be renamed.
# (e.g. sds2.xfs to sdb2.xfs, ...)
while read source target junk ; do
    # Disks in MAPPING_FILE are listed with full device path. Since XFS config
    # files are created in format e.g. sda2.xfs strip prefixed path to have
    # only short device name available.
    base_source=$(basename "$source")
    base_target=$(basename "$target")

    # Check if XFS configuration file for whole device (unpartitioned)
    # is available (sda, sdb, ...). If so, rename and copy it to
    # LAYOUT_XFS_OPT_DIR_RESTORE.
    if [ -e "$LAYOUT_XFS_OPT_DIR/$base_source.xfs" ]; then
        Log "Migrating XFS configuration file $base_source.xfs to $base_target.xfs"
        cp "$v" "$LAYOUT_XFS_OPT_DIR/$base_source.xfs" \
         "$LAYOUT_XFS_OPT_DIR_RESTORE/$base_target.xfs"

        # Replace old disk name in XFS configuration file as well.
        sed -i s#"$base_source"#"$base_target"# \
          "$LAYOUT_XFS_OPT_DIR_RESTORE/$base_target.xfs"

        # Mark XFS config file as processed to avoid copying it again later.
        # More details on why are configs excluded can be found near the
        # end of this script (near `tar' command).
        excluded_configs+=("--exclude=$base_source.xfs")
    fi

    # Find corresponding partitions to source disk in LAYOUT_FILE
    # and migrate/rename them too if necessary.
    while read _ layout_device _ _ _ _ layout_partition; do
        if [[ "$source" = "$layout_device" ]]; then
            base_src_layout_partition=$(basename "$layout_partition")
            base_dst_layout_partition=${base_src_layout_partition//$base_source/$base_target}
            if [ -e "$LAYOUT_XFS_OPT_DIR/$base_src_layout_partition.xfs" ]; then
                Log "Migrating XFS configuration $base_src_layout_partition.xfs to $base_dst_layout_partition.xfs"
                cp "$v" "$LAYOUT_XFS_OPT_DIR/$base_src_layout_partition.xfs" \
                 "$LAYOUT_XFS_OPT_DIR_RESTORE/$base_dst_layout_partition.xfs"

                # Replace old disk name in XFS configuration file as well.
                sed -i s#"$base_src_layout_partition"#"$base_dst_layout_partition"# \
                  "$LAYOUT_XFS_OPT_DIR_RESTORE/$base_dst_layout_partition.xfs"

                # Mark XFS config file as processed to avoid copying it again later.
                # More details on why are configs excluded can be found near the
                # end of this script (near `tar' command).
                excluded_configs+=("--exclude=$base_src_layout_partition.xfs")
            fi
        fi
    done < <( grep -E "^part " "$LAYOUT_FILE" )
done < <( grep -v '^#' "$MAPPING_FILE" )

pushd "$LAYOUT_XFS_OPT_DIR" >/dev/null
# Copy remaining files
# We need to copy remaining files into LAYOUT_XFS_OPT_DIR_RESTORE which will
# serve as base dictionary where ReaR will look for XFS config files.
# It is necessary to copy only files that were not previously processed,
# because in LAYOUT_XFS_OPT_DIR they are still listed with
# original name and copy to LAYOUT_XFS_OPT_DIR_RESTORE could overwrite
# XFS configs already migrated.
# e.g. with following disk mapping situation:
# /dev/sda2 => /dev/sdb2
# /dev/sdb2 => /dev/sda2
# Files in LAYOUT_XFS_OPT_DIR_RESTORE would be overwritten by XFS configs with
# wrong names.
# tar is used to take advantage of its exclude feature.
tar cf - --exclude=restore "${excluded_configs[@]}" . | tar xfp - -C "$LAYOUT_XFS_OPT_DIR_RESTORE"
popd >/dev/null
