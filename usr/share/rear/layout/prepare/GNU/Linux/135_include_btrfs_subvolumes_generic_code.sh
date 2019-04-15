
# New implementation for generic btrfs subvolume handling.
# This is "new" compared to the old code in 136_include_btrfs_subvolumes_SLES_code.sh.

# Btrfs filesystems with subvolumes need a special handling.
# This script layout/prepare/GNU/Linux/135_include_btrfs_subvolumes_generic_code.sh
# contains the function btrfs_subvolumes_setup_generic for generic btrfs subvolumes setup (e.g. for Ubuntu 18.04)
# cf. https://github.com/rear/rear/pull/2079
# The script layout/prepare/GNU/Linux/136_include_btrfs_subvolumes_SLES_code.sh
# contains the function btrfs_subvolumes_setup_SLES for SLES 12 (and later) special btrfs subvolumes setup.
# For a plain btrfs filesystem without subvolumes the btrfs_subvolumes_setup_generic function does nothing.

btrfs_subvolumes_setup_generic() {
    # Invocation: btrfs_subvolumes_setup_generic $device $top_level_mountpoint [...]
    #
    # This function
    # (1) assumes that code present so far in $LAYOUT_FILE has
    #     a) created a Btrfs file system on $device and
    #     b) mounted its Btrfs top-level subvolume at $top_level_mountpoint,
    # (2) interprets lines in $LAYOUT_FILE regarding Btrfs subvolumes for $device, and
    # (3) appends shell code to the file $LAYOUT_CODE, which
    #     a) recreates and
    #     b) mounts
    #     all Btrfs subvolumes for $device, which had been mounted on the original system.

    local device="$1"  # disk device
    local top_level_mountpoint="$2"  # the btrfs file system's top-level subvolume mount point

    if test -z "$device" -o -z "$top_level_mountpoint"; then
        StopIfError "btrfs_subvolumes_setup_generic: missing required parameter: device='$device', top_level_mountpoint='$top_level_mountpoint'"
    fi

    Log "Begin btrfs_subvolumes_setup_generic( $* )"

    # Generate code to create all mounted non top-level subvolumes sorted
    # - in subvolume path order,
    # - discarding duplicate subvolume paths (to be mounted at multiple mount points):
    local ignore_keyword ignore_device subvolume_mountpoint subvolume_mount_options subvolume_path ignore_rest
    while read ignore_keyword ignore_device subvolume_mountpoint subvolume_mount_options subvolume_path ignore_rest; do
        # Check parameters
        if test -z "$subvolume_mountpoint" -o -z "$subvolume_mount_options" -o -z "$subvolume_path"; then
            StopIfError "btrfsmountedsubvol entry for $device: missing required parameter: subvolume_mountpoint='$subvolume_mountpoint', subvolume_mount_options='$subvolume_mount_options', subvolume_path='$subvolume_path'"
        fi

        local relative_subvolume_path="${subvolume_path#/}"  # strip leading '/'
        local relative_subvolume_parent_directory="$(dirname "$relative_subvolume_path")"

        local target_top_level_mountpoint="$TARGET_FS_ROOT${top_level_mountpoint%/}"  # strip trailing '/'
        local target_subvolume_parent_directory="$target_top_level_mountpoint/$relative_subvolume_parent_directory"
        local target_subvolume_path="$target_top_level_mountpoint/$relative_subvolume_path"

        # Create non top-level subvolume (the top-level subvolume will have '/' as its path and does already exist)
        if [[ "$subvolume_path" != "/" ]]; then
            info_message="Creating btrfs subvolume $subvolume_path for $device at $top_level_mountpoint"
            Log "$info_message"
            echo "# $info_message"
            if [[ "$relative_subvolume_parent_directory" != "." ]]; then
                echo "[[ -d '$target_subvolume_parent_directory' ]] || mkdir -p '$target_subvolume_parent_directory'"
            fi
            echo "btrfs subvolume create '$target_subvolume_path'"

            # Mark the created subvolume as default subvolume fi necessary
            if grep -q "^btrfsdefaultsubvol $device .* $subvolume_path\$" "$LAYOUT_FILE"; then
                info_message="Setting default subvolume to $subvolume_path"
                Log "$info_message"
                echo "# $info_message"
                echo "subvolumeID=\$( btrfs subvolume list -a '$target_subvolume_path' | sed -e 's/<FS_TREE>\///' | grep ' $subvolume_path\$' | tr -s '[:blank:]' ' ' | cut -d ' ' -f 2 )"
                echo "btrfs subvolume set-default \$subvolumeID '$target_subvolume_path'"
            fi
        fi

        # Set a 'no copy on write' attribute if necessary
        if grep -q "^btrfsnocopyonwrite $subvolume_path\$" "$LAYOUT_FILE"; then
            info_message="Setting 'no copy on write' attribute for subvolume $subvolume_path"
            Log "$info_message"
            echo "# $info_message"
            echo "chattr +C '$target_subvolume_path'"
        fi
    done < <( grep "^btrfsmountedsubvol $device " "$LAYOUT_FILE" | LC_COLLATE=C sort -k 5 -u ) >> "$LAYOUT_CODE"

    # Generate code to mount subvolumes, sorted in mount-point order (top-down):
    while read ignore_keyword ignore_device subvolume_mountpoint subvolume_mount_options subvolume_path ignore_rest; do
        Log "Mounting subvolume $subvolume_path for $device at $subvolume_mountpoint"

        # Strip 'subvolid=' and 'subvol=' from Btrfs mount options, as we'll add our own 'subvol=' option later.
        # First add a comma at the end so that it is easier to remove a mount option at the end:
        local subvolume_mount_options=${subvolume_mount_options/%/,}
        # Remove all subvolid= and subvol= mount options (the extglob shell option is enabled in rear):
        subvolume_mount_options=${subvolume_mount_options//subvolid=*([^,]),/}
        subvolume_mount_options=${subvolume_mount_options//subvol=*([^,]),/}
        # Remove all commas at the end:
        subvolume_mount_options=${subvolume_mount_options/%,/}

        local target_subvolume_mountpoint="$TARGET_FS_ROOT${subvolume_mountpoint%/}"  # strip trailing '/'
        local mount_required=yes

        if [[ "$subvolume_mountpoint" == "$top_level_mountpoint" ]]; then
            if [[ "$subvolume_path" == "/" ]]; then
                # The mount root for this Btrfs file system is the (initially mounted) top-level subvolume.
                # There is nothing else to do for this subvolume.
                mount_required=no
            else
                # If the mount root for this Btrfs file system is not the (initially mounted) top-level subvolume, we must
                # unmount the top-level subvolume first before proceeding.
                info_message="Unmounting the top-level subvolume for $device (it is about to be replaced by the mount root)"
                Log "$info_message"
                echo "# $info_message"
                echo "umount '$target_subvolume_mountpoint'"
            fi
        fi

        if [[ "$mount_required" == "yes" ]]; then
            info_message="Mounting subvolume $subvolume_path at $subvolume_mountpoint for $device"
            Log "$info_message"
            echo "# $info_message"
            if [[ "$subvolume_mountpoint" != "$top_level_mountpoint" ]]; then
                echo "[[ -d '$target_subvolume_mountpoint' ]] || mkdir -p '$target_subvolume_mountpoint'"
            fi
            echo "mount -t btrfs -o '$subvolume_mount_options,subvol=$subvolume_path' '$device' '$target_subvolume_mountpoint'"
        fi
    done < <( grep "^btrfsmountedsubvol $device " "$LAYOUT_FILE" | LC_COLLATE=C sort -k 3 ) >> "$LAYOUT_CODE"

    Log "End btrfs_subvolumes_setup_generic( $* )"
    true
}

