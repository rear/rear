# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# Btrfs file system support

function btrfs_subvolume_exists() {
    # returns true if the btrfs subvolume ($2) exists in the Btrfs file system at the mount point ($1).
    local subvolume_mountpoint="$1" btrfs_subvolume_path="$2"

    # A root subvolume can be assumed to always exist
    [ "$btrfs_subvolume_path" == "/" ] && return 0

    # A non-root subvolume exists if the btrfs subvolume list contains its complete path at the end of one line.
    # This code deliberately uses a plain string comparison rather than a regexp.
    btrfs subvolume list "$subvolume_mountpoint" |
    awk -v path="$btrfs_subvolume_path" '
        BEGIN {
            path_length = length(path);
            matching_line_count = 0;
        }

        (substr($0, length($0) - path_length + 1) == path) {
            matching_line_count++;
        }

        END {
            exit(matching_line_count == 1 ? 0 : 1);
        }'

    # Return awk's exit status
}
