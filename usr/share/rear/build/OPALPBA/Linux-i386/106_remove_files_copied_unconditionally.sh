# Remove files which have been copied unconditionally

# Safety check - avoid removing files in the wrong place
[[ -n "$ROOTFS_DIR" && -d "$ROOTFS_DIR" ]] || BugError "ROOTFS_DIR='$ROOTFS_DIR' does not specify a valid directory"

# Remove symlinks whose targets have been excluded on the PBA system
local symlinks_to_remove=(
    bin/vim
    var/lib/rear
)

local symlink_to_remove
for symlink_to_remove in "${symlinks_to_remove[@]}"; do
    [[ -h "$ROOTFS_DIR/$symlink_to_remove" ]] && rm "$ROOTFS_DIR/$symlink_to_remove"
done

# Remove ReaR configuration (may contain sensitive information)
rm -r "$ROOTFS_DIR/etc/rear"
