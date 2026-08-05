#!/usr/bin/env bats

#
# Unit tests for filesystem functions
#

bats_require_minimum_version 1.5.0

function setup_file() {
    REAR_SHARE_DIR="$(realpath "$BATS_TEST_DIRNAME/../../usr/share/rear")"
    export REAR_SHARE_DIR
}

function setup() {
    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/lib/filesystems-functions.sh"

    function LogPrintError() {
        echo "$@"
    }
}

@test "Check Btrfs version: btrfs is missing" {
    function has_binary() {
        [ "$1" != "btrfs" ]
    }

    run -127 get_btrfs_version
}

@test "Check Btrfs version: unexpected output" {
    function has_binary() {
        [ "$1" = "btrfs" ]
    }

    function btrfs() {
        [ "$1" = "version" ] || return 1
        echo "btrfs-progs unexpected output"
    }

    run -1 get_btrfs_version
}

@test "Check Btrfs version: v6.14" {
    function has_binary() {
        [ "$1" = "btrfs" ]
    }

    function btrfs() {
        [ "$1" = "version" ] || return 1
        echo "btrfs-progs v6.14"
        echo "-EXPERIMENTAL -INJECT -STATIC +LZO +ZSTD +UDEV +FSVERITY +ZONED CRYPTO=builtin"
    }

    run -0 get_btrfs_version
    [ "$output" = "6.14" ]
}

@test "Check Btrfs version: v5.16.2" {
    function has_binary() {
        [ "$1" = "btrfs" ]
    }

    function btrfs() {
        [ "$1" = "version" ] || return 1
        echo "btrfs-progs v5.16.2"
    }

    run -0 get_btrfs_version
    [ "$output" = "5.16.2" ]
}

@test "Check Btrfs version: v4.5.3+20160729" {
    function has_binary() {
        [ "$1" = "btrfs" ]
    }

    function btrfs() {
        [ "$1" = "version" ] || return 1
        echo "btrfs-progs v4.5.3"
    }

    run -0 get_btrfs_version
    [ "$output" = "4.5.3" ]
}

@test "Get available Btrfs features: mkfs.btrfs is missing" {
    function has_binary() {
        [ "$1" != "mkfs.btrfs" ]
    }

    run -127 get_available_btrfs_features
}

@test "Get available Btrfs features: failed to get filesystem features" {
    function has_binary() {
        [ "$1" = "mkfs.btrfs" ]
    }

    function mkfs.btrfs() {
        [ "$1 $2" != "-O list-all" ]
    }

    run -1 get_available_btrfs_features
    [ "$output" = "Failed to get the list of available Btrfs filesystem features using mkfs.btrfs -O list-all." ]
}

@test "Get available Btrfs features: v6.14" {
    function has_binary() {
        [ "$1" = "mkfs.btrfs" ]
    }

    function mkfs.btrfs() {
        [ "$1 $2" = "-O list-all" ] || return 1
        {
            echo "Filesystem features available:"
            echo "mixed-bg            - mixed data and metadata block groups (compat=2.6.37, safe=2.6.37)"
            echo "quota               - hierarchical quota group support (qgroups) (compat=3.4)"
            echo "extref              - increased hardlink limit per file to 65536 (compat=3.7, safe=3.12, default=3.12)"
            echo "raid56              - raid56 extended format (compat=3.9)"
            echo "skinny-metadata     - reduced-size metadata extent refs (compat=3.10, safe=3.18, default=3.18)"
            echo "no-holes            - no explicit hole extents for files (compat=3.14, safe=4.0, default=5.15)"
            echo "fst                 - free-space-tree alias"
            echo "free-space-tree     - free space tree, improved space tracking (space_cache=v2) (compat=4.5, safe=4.9, default=5.15)"
            echo "raid1c34            - RAID1 with 3 or 4 copies (compat=5.5)"
            echo "zoned               - support zoned (SMR/ZBC/ZNS) devices (compat=5.12)"
            echo "bgt                 - block-group-tree alias"
            echo "block-group-tree    - block group tree, more efficient block group tracking to reduce mount time (compat=6.1)"
            echo "squota              - squota support (simple accounting qgroups) (compat=6.7)"
        } >&2
    }

    function get_btrfs_version() {
        echo "6.14"
    }

    local features="mixed-bg
quota
extref
raid56
skinny-metadata
no-holes
free-space-tree
raid1c34
zoned
block-group-tree
squota"

    run -0 get_available_btrfs_features
    [ "$output" = "$features" ]
}

@test "Get available Btrfs features: failed to get version to check whether mkfs.btrfs -R list-all must be used" {
    function has_binary() {
        [ "$1" = "mkfs.btrfs" ]
    }

    function mkfs.btrfs() {
        [ "$1 $2" = "-O list-all" ] || return 1
        {
            echo "Filesystem features available:"
            echo "mixed-bg            - mixed data and metadata block groups (0x4, compat=2.6.37, safe=2.6.37)"
            echo "extref              - increased hardlink limit per file to 65536 (0x40, compat=3.7, safe=3.12, default=3.12)"
            echo "raid56              - raid56 extended format (0x80, compat=3.9)"
            echo "skinny-metadata     - reduced-size metadata extent refs (0x100, compat=3.10, safe=3.18, default=3.18)"
            echo "no-holes            - no explicit hole extents for files (0x200, compat=3.14, safe=4.0, default=5.15)"
            echo "raid1c34            - RAID1 with 3 or 4 copies (0x800, compat=5.5)"
            echo "zoned               - support zoned devices (0x1000, compat=5.12)"
        } >&2
    }

    function get_btrfs_version() {
        return 1
    }

    run -1 get_available_btrfs_features
    [ "$output" = "Failed to determine the Btrfs version to check whether mkfs.btrfs -R list-all must be used." ]
}

@test "Get available Btrfs features: failed to get runtime features on v5.16.2" {
    function has_binary() {
        [ "$1" = "mkfs.btrfs" ]
    }

    function mkfs.btrfs() {
        [ "$1 $2" = "-O list-all" ] || return 1
        {
            echo "Filesystem features available:"
            echo "mixed-bg            - mixed data and metadata block groups (0x4, compat=2.6.37, safe=2.6.37)"
            echo "extref              - increased hardlink limit per file to 65536 (0x40, compat=3.7, safe=3.12, default=3.12)"
            echo "raid56              - raid56 extended format (0x80, compat=3.9)"
            echo "skinny-metadata     - reduced-size metadata extent refs (0x100, compat=3.10, safe=3.18, default=3.18)"
            echo "no-holes            - no explicit hole extents for files (0x200, compat=3.14, safe=4.0, default=5.15)"
            echo "raid1c34            - RAID1 with 3 or 4 copies (0x800, compat=5.5)"
            echo "zoned               - support zoned devices (0x1000, compat=5.12)"
        } >&2
    }

    function get_btrfs_version() {
        echo "5.16.2"
    }

    run -1 get_available_btrfs_features
    [ "$output" = "Failed to get the list of available Btrfs runtime features using mkfs.btrfs -R list-all." ]
}

@test "Get available Btrfs features: v5.16.2" {
    function has_binary() {
        [ "$1" = "mkfs.btrfs" ]
    }

    function mkfs.btrfs() {
        [ "$1 $2" = "-O list-all" ] && {
            echo "Filesystem features available:"
            echo "mixed-bg            - mixed data and metadata block groups (0x4, compat=2.6.37, safe=2.6.37)"
            echo "extref              - increased hardlink limit per file to 65536 (0x40, compat=3.7, safe=3.12, default=3.12)"
            echo "raid56              - raid56 extended format (0x80, compat=3.9)"
            echo "skinny-metadata     - reduced-size metadata extent refs (0x100, compat=3.10, safe=3.18, default=3.18)"
            echo "no-holes            - no explicit hole extents for files (0x200, compat=3.14, safe=4.0, default=5.15)"
            echo "raid1c34            - RAID1 with 3 or 4 copies (0x800, compat=5.5)"
            echo "zoned               - support zoned devices (0x1000, compat=5.12)"
            return 0
        } >&2

        [ "$1 $2" = "-R list-all" ] && {
            echo "Runtime features available:"
            echo "quota               - quota support (qgroups) (0x1, compat=3.4)"
            echo "free-space-tree     - free space tree (space_cache=v2) (0x2, compat=4.5, safe=4.9, default=5.15)"
            return 0
        } >&2

        return 1
    }

    function get_btrfs_version() {
        echo "5.16.2"
    }

    local features="mixed-bg
extref
raid56
skinny-metadata
no-holes
raid1c34
zoned
quota
free-space-tree"

    run -0 get_available_btrfs_features
    [ "$output" = "$features" ]
}

@test "Get available Btrfs features: v4.5.3" {
    function has_binary() {
        [ "$1" = "mkfs.btrfs" ]
    }

    function mkfs.btrfs() {
        [ "$1 $2" = "-O list-all" ] && {
            echo "Filesystem features available:"
            echo "mixed-bg            - mixed data and metadata block groups (0x4)"
            echo "extref              - increased hardlink limit per file to 65536 (0x40, default)"
            echo "raid56              - raid56 extended format (0x80)"
            echo "skinny-metadata     - reduced-size metadata extent refs (0x100, default)"
            echo "no-holes            - no explicit hole extents for files (0x200)"
            return 0
        } >&2

        return 1
    }

    function get_btrfs_version() {
        echo "4.5.3"
    }

    local features="mixed-bg
extref
raid56
skinny-metadata
no-holes"

    run -0 get_available_btrfs_features
    [ "$output" = "$features" ]
}

@test "Get available Btrfs features: v6.2.2" {
    function has_binary() {
        [ "$1" = "mkfs.btrfs" ]
    }

    function mkfs.btrfs() {
        [ "$1 $2" = "-O list-all" ] && {
            echo "Filesystem features available:"
            echo "mixed-bg            - mixed data and metadata block groups (compat=2.6.37, safe=2.6.37)"
            echo "extref              - increased hardlink limit per file to 65536 (compat=3.7, safe=3.12, default=3.12)"
            echo "raid56              - raid56 extended format (compat=3.9)"
            echo "skinny-metadata     - reduced-size metadata extent refs (compat=3.10, safe=3.18, default=3.18)"
            echo "no-holes            - no explicit hole extents for files (compat=3.14, safe=4.0, default=5.15)"
            echo "raid1c34            - RAID1 with 3 or 4 copies (compat=5.5)"
            echo "zoned               - support zoned devices (compat=5.12)"
            return 0
        } >&2
        [ "$1 $2" = "-R list-all" ] && {
            echo "Runtime features available:"
            echo "quota               - quota support (qgroups) (compat=3.4)"
            echo "free-space-tree     - free space tree (space_cache=v2) (compat=4.5, safe=4.9, default=5.15)"
            return 0
        } >&2

        return 1
    }

    function get_btrfs_version() {
        echo "6.2.2"
    }

    local features="mixed-bg
extref
raid56
skinny-metadata
no-holes
raid1c34
zoned
quota
free-space-tree"

    run -0 get_available_btrfs_features
    [ "$output" = "$features" ]
}

@test "Get enabled Btrfs features: a filesystem UUID is not passed" {
    run -3 get_enabled_btrfs_features
}

@test "Get enabled Btrfs features: no such directory" {
    local uuid="32ecb07a-e4d4-4c14-b1a8-8cb0148e5bfe"

    function find() {
        [ "$*" != "/sys/fs/btrfs/$uuid/features/ -maxdepth 1 -type f -exec grep -qx 1 {} ; -printf %f\\n" ]
    }

    run -1 get_enabled_btrfs_features "$uuid"
    [ "$output" = "Failed to get enabled Btrfs filesystem features from '/sys/fs/btrfs/$uuid/features/'." ]
}

@test "Get enabled Btrfs features: failed to get available Btrfs filesystem features" {
    local uuid="32ecb07a-e4d4-4c14-b1a8-8cb0148e5bfe"

    function find() {
        [ "$*" = "/sys/fs/btrfs/$uuid/features/ -maxdepth 1 -type f -exec grep -qx 1 {} ; -printf %f\\n" ] || return 1
        echo "default_subvol"
        echo "free_space_tree"
        echo "no_holes"
        echo "skinny_metadata"
        echo "extended_iref"
    }

    function get_available_btrfs_features() {
        return 1
    }

    run -1 get_enabled_btrfs_features "$uuid"
    [ "$output" = "Failed to get the list of available Btrfs features to filter out enabled features for the filesystem with UUID $uuid." ]
}

@test "Get enabled Btrfs features: filter out features that are not allowed be passed to mkfs.btrfs -O" {
    local uuid="32ecb07a-e4d4-4c14-b1a8-8cb0148e5bfe"

    function find() {
        [ "$*" = "/sys/fs/btrfs/$uuid/features/ -maxdepth 1 -type f -exec grep -qx 1 {} ; -printf %f\\n" ] || return 1
        echo "default_subvol"
        echo "mixed_backref"
        echo "mixed_groups"
        echo "free_space_tree"
        echo "no_holes"
        echo "skinny_metadata"
        echo "extended_iref"
        echo "big_metadata"
        echo "simple_quota"
    }

    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "raid56"
        echo "skinny-metadata"
        echo "no-holes"
        echo "free-space-tree"
        echo "raid1c34"
        echo "zoned"
        echo "block-group-tree"
        echo "squota"
    }

    function are_btrfs_qgroups_enabled() {
        return 1
    }

    run -0 get_enabled_btrfs_features "$uuid"
    [ "$output" = "extref,free-space-tree,mixed-bg,no-holes,skinny-metadata,squota" ]
}

@test "Get enabled Btrfs features: qgroups are enabled" {
    local uuid="32ecb07a-e4d4-4c14-b1a8-8cb0148e5bfe"

    function find() {
        [ "$*" = "/sys/fs/btrfs/$uuid/features/ -maxdepth 1 -type f -exec grep -qx 1 {} ; -printf %f\\n" ] || return 1
        echo "extended_iref"
    }

    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "raid56"
        echo "skinny-metadata"
        echo "no-holes"
        echo "free-space-tree"
        echo "raid1c34"
        echo "zoned"
        echo "block-group-tree"
        echo "squota"
    }

    function are_btrfs_qgroups_enabled() {
        return 0
    }

    run -0 get_enabled_btrfs_features "$uuid"
    [ "$output" = "extref,quota" ]
}

@test "Get Btrfs features option for mkfs: failed to get the list of available Btrfs features" {
    function get_available_btrfs_features() {
        return 1
    }

    run -1 get_btrfs_features_option_for_mkfs
    [ "$output" = "Failed to get the list of available Btrfs features to prepare the mkfs.btrfs -O option." ]
}


@test "Get Btrfs features option for mkfs: failed to get version to check whether mkfs.btrfs -R list-all must be used" {
    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "no-holes"
        echo "free-space-tree"
    }

    function get_btrfs_version() {
        return 1
    }

    run -1 get_btrfs_features_option_for_mkfs
    [ "$output" = "Failed to determine the Btrfs version to check whether mkfs.btrfs -R list-all must be used." ]
}

@test "Get Btrfs features option for mkfs: disable all features v6.14" {
    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "no-holes"
        echo "free-space-tree"
    }

    function get_btrfs_version() {
        echo "6.14"
    }

    run -0 get_btrfs_features_option_for_mkfs
    [ "$output" = " -O ^extref,^free-space-tree,^mixed-bg,^no-holes,^quota" ]
}

@test "Get Btrfs features option for mkfs: disable all features v5.16.2" {
    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "no-holes"
        echo "free-space-tree"
    }

    function get_btrfs_version() {
        echo "5.16.2"
    }

    run -0 get_btrfs_features_option_for_mkfs
    [ "$output" = " -R ^free-space-tree,^quota -O ^extref,^mixed-bg,^no-holes" ]
}

@test "Get Btrfs features option for mkfs: enable all features v6.14" {
    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "raid56"
        echo "skinny-metadata"
        echo "no-holes"
        echo "free-space-tree"
        echo "raid1c34"
        echo "zoned"
        echo "block-group-tree"
        echo "squota"
    }

    function get_btrfs_version() {
        echo "6.14"
    }

    run -0 get_btrfs_features_option_for_mkfs mixed-bg,quota,extref,raid56,skinny-metadata,no-holes,free-space-tree,raid1c34,zoned,block-group-tree,squota
    [ "$output" = " -O mixed-bg,quota,extref,raid56,skinny-metadata,no-holes,free-space-tree,raid1c34,zoned,block-group-tree,squota" ]
}

@test "Get Btrfs features option for mkfs: enable all features v5.16.2" {
    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "raid56"
        echo "skinny-metadata"
        echo "no-holes"
        echo "free-space-tree"
        echo "raid1c34"
        echo "zoned"
        echo "squota"
    }

    function get_btrfs_version() {
        echo "5.16.2"
    }

    run -0 get_btrfs_features_option_for_mkfs mixed-bg,quota,extref,raid56,skinny-metadata,no-holes,free-space-tree,raid1c34,zoned,squota
    [ "$output" = " -R free-space-tree,quota -O mixed-bg,extref,raid56,skinny-metadata,no-holes,raid1c34,zoned,squota" ]
}

@test "Get Btrfs features option for mkfs: skip unsupported Btrfs features" {
    function get_available_btrfs_features() {
        echo "quota"
        echo "free-space-tree"
    }

    function get_btrfs_version() {
        echo "5.16.2"
    }

    run -0 get_btrfs_features_option_for_mkfs quota,free-space-tree,block-group-tree,squota
    [ "${lines[0]}" = "'block-group-tree' is an unsupported Btrfs filesystem feature in the version of mkfs.btrfs used by the rescue system and cannot be recovered." ]
    [ "${lines[1]}" = "'squota' is an unsupported Btrfs filesystem feature in the version of mkfs.btrfs used by the rescue system and cannot be recovered." ]
    [ "${lines[2]}" = " -R free-space-tree,quota" ]
}

@test "Get Btrfs features option for mkfs: default case for v5.16.2" {
    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "extref"
        echo "raid56"
        echo "skinny-metadata"
        echo "no-holes"
        echo "raid1c34"
        echo "zoned"
        echo "quota"
        echo "free-space-tree"
    }

    function get_btrfs_version() {
        echo "5.16.2"
    }

    run -0 get_btrfs_features_option_for_mkfs extref,free-space-tree,no-holes,skinny-metadata
    [ "$output" = " -R free-space-tree,^quota -O extref,no-holes,skinny-metadata,^mixed-bg,^raid1c34,^raid56,^zoned" ]
}

@test "Get Btrfs features option for mkfs: default case for v6.14" {
    function get_available_btrfs_features() {
        echo "mixed-bg"
        echo "quota"
        echo "extref"
        echo "raid56"
        echo "skinny-metadata"
        echo "no-holes"
        echo "free-space-tree"
        echo "raid1c34"
        echo "zoned"
        echo "block-group-tree"
        echo "squota"
    }

    function get_btrfs_version() {
        echo "6.14"
    }

    run -0 get_btrfs_features_option_for_mkfs extref,free-space-tree,no-holes,skinny-metadata
    [ "$output" = " -O extref,free-space-tree,no-holes,skinny-metadata,^block-group-tree,^mixed-bg,^quota,^raid1c34,^raid56,^squota,^zoned" ]
}

@test "Get Btrfs nodesize: UUID is missing" {
    run -3 get_btrfs_nodesize
}

@test "Get Btrfs sectorsize: UUID is missing" {
    run -3 get_btrfs_sectorsize
}

@test "Are Btrfs qgroups enabled: UUID is missing" {
    run -3 are_btrfs_qgroups_enabled
}

@test "Is Btrfs node size valid: empty nodesize is invalid" {
    run -1 is_btrfs_nodesize_valid
}

@test "Is Btrfs nodesize valid: 16384 is valid" {
    is_btrfs_nodesize_valid 16384
}

@test "Is Btrfs nodesize valid: nodesize must be a power of 2" {
    run -1 is_btrfs_nodesize_valid 1023
}

@test "Is Btrfs nodesize valid: nodesize must be not larger than 64KiB" {
    run -1 is_btrfs_nodesize_valid 131072
}

@test "Is Btrfs nodesize valid: nodesize containing non-numeric characters is invalid" {
    run -1 is_btrfs_nodesize_valid "16384;rm -rf /"
}

@test "Is Btrfs sectorsize valid: empty sectorsize is invalid" {
    run -1 is_btrfs_sectorsize_valid
}

@test "Is Btrfs sectorsize valid: 16384 is valid" {
    is_btrfs_sectorsize_valid 16384
}

@test "Is Btrfs sectorsize valid: sectorsize must be a power of 2" {
    run -1 is_btrfs_sectorsize_valid 1023
}

@test "Is Btrfs sectorsize valid: sectorsize containing non-numeric characters is invalid" {
    run -1 is_btrfs_sectorsize_valid "4096;rm -rf /"
}

@test "Is Btrfs list of features valid: valid list is passed" {
    is_btrfs_list_of_features_valid "mixed-bg,extref,raid1c34"
}

@test "Is Btrfs list of features valid: malicious code injected" {
    run -1 is_btrfs_list_of_features_valid "mixed-bg,;rm -rf /;extref"
}
