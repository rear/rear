# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# File system support functions

function btrfs_snapshot_subvolume_exists() {
    # returns true if the btrfs snapshot subvolume ($2) exists in the Btrfs
    # file system at the mount point ($1).

    # Use -s so that btrfs subvolume list considers snapshots only
    btrfs_subvolume_exists "$1" "$2" "-s"
}

function btrfs_subvolume_exists() {
    # returns true if the btrfs subvolume ($2) exists in the Btrfs file system at the mount point ($1).
    local subvolume_mountpoint="$1" btrfs_subvolume_path="$2"

    # extra options for the btrfs subvolume list command ($3)
    local btrfs_extra_opts="$3"

    # A root subvolume can be assumed to always exist
    [ "$btrfs_subvolume_path" == "/" ] && return 0

    # A non-root subvolume exists if the btrfs subvolume list contains its complete path at the end of one line.
    # This code deliberately uses a plain string comparison rather than a regexp.
    btrfs subvolume list -a $btrfs_extra_opts "$subvolume_mountpoint" | sed -e 's; path <FS_TREE>/; path ;' |
    awk -v path="$btrfs_subvolume_path" '
        BEGIN {
            match_string = " path " path;
            match_string_length = length(match_string);
            matching_line_count = 0;
        }

        (substr($0, length($0) - match_string_length + 1) == match_string) {
            matching_line_count++;
        }

        END {
            exit(matching_line_count == 1 ? 0 : 1);
        }'

    # Return awk's exit status
}

function get_btrfs_version() {
    if ! has_binary btrfs; then
        return 127
    fi

    btrfs version | grep -oP '(?<=btrfs-progs v)[\d.]+'
}

function get_available_btrfs_features() {
    if ! has_binary mkfs.btrfs; then
        return 127
    fi

    local buffer
    if ! buffer="$(mkfs.btrfs -O list-all 2>&1)"; then
        LogPrintError "Failed to get the list of available Btrfs filesystem features using mkfs.btrfs -O list-all."
        return 1
    fi

    local features
    # Filter out aliases such as 'bgt - block-group-tree alias'.
    features="$(echo "$buffer" | awk 'NR>1 && !/alias$/ {print $1}')"

    # We need to get runtime features using mkfs.btrfs -R list-all for versions
    # between 5.7 and 6.2. Since 6.3, the -R option has been deprecated,
    # and all features have been merged into the -O option.
    local btrfs_version
    if ! btrfs_version=$(get_btrfs_version); then
        LogPrintError "Failed to determine the Btrfs version to check whether mkfs.btrfs -R list-all must be used."
        return 1
    fi

    if printf '%s\n' "5.7" "$btrfs_version" "6.2" | sort -V -C; then
        if ! buffer="$(mkfs.btrfs -R list-all 2>&1)"; then
            LogPrintError "Failed to get the list of available Btrfs runtime features using mkfs.btrfs -R list-all."
            return 1
        fi
        features+=$'\n'
        features+="$(echo "$buffer" | awk 'NR>1 {print $1}')"
    fi

    echo "$features"
}

# $1 - a filesystem UUID
function are_btrfs_qgroups_enabled() {
    local uuid=$1
    if [ -z "$uuid" ]; then
        return 3
    fi

    local qgroups_dir="/sys/fs/btrfs/$uuid/qgroups"
    if [ ! -f "${qgroups_dir}/enabled" ] || [ ! -f "${qgroups_dir}/mode" ]; then
        return 1
    fi

    [ "$(cat "${qgroups_dir}/enabled")" = "1" ] && [ "$(cat "${qgroups_dir}/mode")" = "qgroup" ]
}

# $1 - a filesystem UUID
function get_enabled_btrfs_features() {
    local uuid=$1
    if [ -z "$uuid" ]; then
        return 3
    fi

    local features_dir="/sys/fs/btrfs/$uuid/features/"

    local enabled_features
    if ! enabled_features=$(find "$features_dir" -maxdepth 1 -type f -exec grep -qx "1" {} \; -printf "%f\n"); then
        LogPrintError "Failed to get enabled Btrfs filesystem features from '$features_dir'."
        return 1
    fi
    # Translate sysfs feature names to mkfs.btrfs -O flag names
    enabled_features="${enabled_features//_/-}"
    enabled_features="${enabled_features/mixed-groups/mixed-bg}"
    enabled_features="${enabled_features/extended-iref/extref}"
    enabled_features="${enabled_features/simple-quota/squota}"

    # Check whether qgroups are enabled separately because there isn't a dedicated flag in /sys/fs/btrfs/UUID/features/
    if are_btrfs_qgroups_enabled "$uuid"; then
        enabled_features+=$'\n'"quota"
    fi

    # Filter out filesystem features that can't be passed to the mkfs.btrfs -O option 
    local available_features
    if ! available_features=$(get_available_btrfs_features); then
        LogPrintError "Failed to get the list of available Btrfs features to filter out enabled features for the filesystem with UUID $uuid."
        return 1
    fi
    enabled_features=$(comm -12 <(echo "$available_features" | sort) <(echo "$enabled_features" | sort))

    enabled_features="${enabled_features//$'\n'/,}"

    echo "$enabled_features"
}

# $1 - a comma-separated list of enabled Btrfs features
function get_btrfs_features_option_for_mkfs() {
    local features=$1

    local available_features
    if ! available_features=$(get_available_btrfs_features); then
        LogPrintError "Failed to get the list of available Btrfs features to prepare the mkfs.btrfs -O option."
        return 1
    fi
    available_features=$(echo "$available_features" | sort)

    local unsupported_features
    unsupported_features=$(comm -13 <(echo "$available_features") <(echo "$features" | tr ',' '\n' | sort))

    local unsupported_feature
    for unsupported_feature in $unsupported_features; do
        LogPrintError "'$unsupported_feature' is an unsupported Btrfs filesystem feature in the version of mkfs.btrfs used by the rescue system and cannot be recovered."
        # Remove unsupported features caused by using an older mkfs.btrfs on the rescue system than mkfs.btrfs used to create a filesystem.
        features=$(echo "$features" | sed -E "s/(^|,)${unsupported_feature}(,|$)/\1/;s/,$//")
    done

    local disabled_features
    disabled_features=$(comm -23 <(echo "$available_features") <(echo "$features" | tr ',' '\n' | sort))

    local disabled_feature
    for disabled_feature in $disabled_features; do
        # Explicitly turn off disabled features to prevent them from being enabled by default.
        features+=",^$disabled_feature"
    done

    local result=""

    # For versions 5.7 through 6.2, runtime features must be controlled using the -R option.
    local btrfs_version
    if ! btrfs_version=$(get_btrfs_version); then
        LogPrintError "Failed to determine the Btrfs version to check whether mkfs.btrfs -R list-all must be used."
        return 1
    fi
    if printf '%s\n' "5.7" "$btrfs_version" "6.2" | sort -V -C; then
        local runtime_features=""
        for runtime_feature in free-space-tree quota; do
            local found
            if found=$(echo "$features" | grep -oP '(?<![a-z])\^?'"$runtime_feature"',?'); then
                features="${features/$found/}"
                runtime_features+=",${found%,}"
            fi
        done

        if [ -n "$runtime_features" ]; then
            result+=" -R ${runtime_features#,}"
        fi

        features=${features%,}
    fi

    if [ -n "$features" ]; then
        result+=" -O ${features#,}"
    fi

    echo "$result"
}

# $1 - a filesystem UUID
function get_btrfs_nodesize() {
    local uuid=$1
    if [ -z "$uuid" ]; then
        return 3
    fi

    local nodesize_path=/sys/fs/btrfs/$uuid/nodesize
    if [ ! -f "$nodesize_path" ]; then
        return 127
    fi

    cat "$nodesize_path"
}

# $1 - a filesystem UUID
function get_btrfs_sectorsize() {
    local uuid=$1
    if [ -z "$uuid" ]; then
        return 3
    fi

    local sectorsize_path=/sys/fs/btrfs/$uuid/sectorsize
    if [ ! -f "$sectorsize_path" ]; then
        return 127
    fi

    cat "$sectorsize_path"
}

# $1 - nodesize
function is_btrfs_nodesize_valid() {
    local nodesize=$1
    [[ "$nodesize" =~ ^[0-9]+$ ]] || return 1
    # The nodesize must be not larger than 64KiB and a power of 2
    (( nodesize > 0 && nodesize <= 65536 && (nodesize & (nodesize - 1)) == 0 ))
}

# $1 - sectorsize
function is_btrfs_sectorsize_valid() {
    local sectorsize=$1
    [[ "$sectorsize" =~ ^[0-9]+$ ]] || return 1
    # The sectorsize must be a power of 2
    (( sectorsize > 0 && (sectorsize & (sectorsize - 1)) == 0 ))
}

# $1 - a comma-separated list of features
function is_btrfs_list_of_features_valid() {
    local list=$1
    [ -z "$list" ] || [[ "$list" =~ ^[0-9a-z-]+(,[0-9a-z-]+)*$ ]]
}

#Parse output from xfs_info for later use by mkfs.xfs

function xfs_parse
{
    local xfs_opt_file=$1
    local xfs_opts=""

    # Check if we can read configuration file produced by xfs_info.
    # Fall back to mkfs.xfs defaults if trouble with configuration file occur.
    if [ ! -r $xfs_opt_file ]; then
        Log "Can't read $xfs_opt_file, falling back to mkfs.xfs defaults."
        return
    fi

    infile=$(cat $xfs_opt_file)

    # Remove some unused characters like commas (,) "empty" equal signs " = "
    infile_format=$(echo $infile | sed -e 's/ = / /g' -e 's/,//g' -e 's/ =/=/g')

    # xfs_info is divided into sections.
    # Sections will be later searched for right option.
    metadata_section=$(echo $infile_format | sed -e 's/.*\(meta-data=.*\) data.*/\1/')
    data_section=$(echo $infile_format     | sed -e 's/.*\(data.*\) naming.*/\1/')
    naming_section=$(echo $infile_format   | sed -e 's/.*\(naming.*\) log=.*/\1/')
    log_section=$(echo $infile_format      | sed -e 's/.*\(log=.*\) realtime.*/\1/')
    realtime_section=$(echo $infile_format | sed -e 's/.*\(realtime.*\).*/\1/')

    # Definitions of options to search for
    # meta-data section of xfs_info output
    xfs_param_iname[0]="isize"
    xfs_param_search[0]="metadata_section"
    xfs_param_opt[0]="-i"
    xfs_param_name[0]="size"

    xfs_param_iname[1]="agcount"
    xfs_param_search[1]="metadata_section"
    xfs_param_opt[1]="-d"
    xfs_param_name[1]="agcount"

    xfs_param_iname[2]="sectsz"
    xfs_param_search[2]="metadata_section"
    xfs_param_opt[2]="-s"
    xfs_param_name[2]="size"

    xfs_param_iname[3]="attr"
    xfs_param_search[3]="metadata_section"
    xfs_param_opt[3]="-i"
    xfs_param_name[3]="attr"

    xfs_param_iname[4]="projid32bit"
    xfs_param_search[4]="metadata_section"
    xfs_param_opt[4]="-i"
    xfs_param_name[4]="projid32bit"

    xfs_param_iname[5]="crc"
    xfs_param_search[5]="metadata_section"
    xfs_param_opt[5]="-m"
    xfs_param_name[5]="crc"

    xfs_param_iname[6]="finobt"
    xfs_param_search[6]="metadata_section"
    xfs_param_opt[6]="-m"
    xfs_param_name[6]="finobt"

    # data section of xfs_info output
    xfs_param_iname[7]="bsize"
    xfs_param_search[7]="data_section"
    xfs_param_opt[7]="-b"
    xfs_param_name[7]="size"

    xfs_param_iname[8]="imaxpct"
    xfs_param_search[8]="data_section"
    xfs_param_opt[8]="-i"
    xfs_param_name[8]="maxpct"

    xfs_param_iname[9]="sunit"
    xfs_param_search[9]="data_section"
    xfs_param_opt[9]="-d"
    xfs_param_name[9]="sunit"

    xfs_param_iname[10]="swidth"
    xfs_param_search[10]="data_section"
    xfs_param_opt[10]="-d"
    xfs_param_name[10]="swidth"

    # log section of xfs_info output
    xfs_param_iname[11]="version"
    xfs_param_search[11]="log_section"
    xfs_param_opt[11]="-l"
    xfs_param_name[11]="version"

    xfs_param_iname[12]="sunit"
    xfs_param_search[12]="log_section"
    xfs_param_opt[12]="-l"
    xfs_param_name[12]="sunit"

    xfs_param_iname[13]="lazy-count"
    xfs_param_search[13]="log_section"
    xfs_param_opt[13]="-l"
    xfs_param_name[13]="lazy-count"

    # naming section of xfs_info output
    xfs_param_iname[14]="bsize"
    xfs_param_search[14]="naming_section"
    xfs_param_opt[14]="-n"
    xfs_param_name[14]="size"

    xfs_param_iname[15]="ascii-ci"
    xfs_param_search[15]="naming_section"
    xfs_param_opt[15]="-n"
    xfs_param_name[15]="ascii-ci"

    xfs_param_iname[16]="ftype"
    xfs_param_search[16]="naming_section"
    xfs_param_opt[16]="-n"
    xfs_param_name[16]="ftype"

    # realtime section of xfs_info output
    xfs_param_iname[17]="extsz"
    xfs_param_search[17]="realtime_section"
    xfs_param_opt[17]="-r"
    xfs_param_name[17]="extsize"

    # xfs_info v4.5.0 on RHEL 7 reports 'spinodes' instead of 'sparse'
    xfs_param_iname[18]="spinodes"
    xfs_param_search[18]="metadata_section"
    xfs_param_opt[18]="-i"
    xfs_param_name[18]="sparse"

    # xfs_info v5.0.0 on RHEL 8 and later versions report 'sparse'
    xfs_param_iname[19]="sparse"
    xfs_param_search[19]="metadata_section"
    xfs_param_opt[19]="-i"
    xfs_param_name[19]="sparse"

    xfs_param_iname[20]="rmapbt"
    xfs_param_search[20]="metadata_section"
    xfs_param_opt[20]="-m"
    xfs_param_name[20]="rmapbt"

    xfs_param_iname[21]="reflink"
    xfs_param_search[21]="metadata_section"
    xfs_param_opt[21]="-m"
    xfs_param_name[21]="reflink"

    xfs_param_iname[22]="bigtime"
    xfs_param_search[22]="metadata_section"
    xfs_param_opt[22]="-m"
    xfs_param_name[22]="bigtime"

    xfs_param_iname[23]="inobtcount"
    xfs_param_search[23]="metadata_section"
    xfs_param_opt[23]="-m"
    xfs_param_name[23]="inobtcount"

    xfs_param_iname[24]="nrext64"
    xfs_param_search[24]="metadata_section"
    xfs_param_opt[24]="-i"
    xfs_param_name[24]="nrext64"

    # Here we will save some variables, that will be later used for
    # calculations (block_size) or due dependencies with other options (crc).

    block_size=$(echo $data_section \
    | grep -oE "bsize=[0-9]*" | cut -d "=" -f2)

    crc=$(echo $metadata_section \
    | grep -oE "crc=[0-9]*" | cut -d "=" -f2)

    # Count how many parameter we have
    for i in "${xfs_param_iname[@]}" ; do
      xfs_param_count=$((xfs_param_count+1))
    done

    i=0
    while [ $i -lt $xfs_param_count ]; do

        # Find variable and its value in `xfs_output' list
        var_val=$(eval "echo \$${xfs_param_search[$i]}" \
        | grep -oE "${xfs_param_iname[$i]}=[0-9]*")

        if [ -n "$var_val" ]; then

            # Substitute variable name from `xfs_info' output
            # so it can serve as input for mkfs.xfs
            var_val_mapped=$(echo $var_val \
            | sed -e 's/'${xfs_param_iname[$i]}'/'${xfs_param_name[$i]}'/')

            var=$(echo $var_val_mapped | cut -d "=" -f1)
            val=$(echo $var_val_mapped | cut -d "=" -f2)

            # Handle mkfs.xfs special cases
            # sunit & swidth are set in blocks
            if [ $var = "sunit" ] || [ $var = "swidth" ]; then
                val=$((val*$block_size/512))
            fi

            # A bit obscure checking naming_options version
            if [ $var = "ascii-ci" ]; then
                var="version"
                if [ $val -eq 1 ]; then
                    val="ci"
                elif [ $val -eq 0 ]; then
                    val="2"
                fi
            fi

            # xfsprogs > 4.7.0 evaluates -l sunit=0 "illegal"
            #
            # mkfs.xfs -l sunit=0 ...
            # "Illegal value 0 for -l sunit option. value is too small"
            #
            # Skipping -l sunit=0 satisfies mkfs.xfs and does not change
            # original XFS file system properties.
            # c.f. ReaR: https://github.com/rear/rear/issues/1579
            # and https://www.spinics.net/lists/linux-xfs/msg13135.html
            if [ ${xfs_param_search[$i]} = "log_section" ] &&
               [ $var = "sunit" ] && [ $val = 0 ]; then
                i=$((i+1))
                continue
            fi

            # crc and ftype are mutually exclusive.
            # crc option might be even completely missing in older versions of
            # xfsprogs, which would cause behaviour like described in
            # https://github.com/rear/rear/issues/1915.
            # To avoid messages like "[: -eq: unary operator expected",
            # we will set default value for $crc variable to 0.
            if [ ${crc:-0} -eq 1 ] && [ $var = "ftype" ]; then
                i=$((i+1))
                continue
            fi

            # Add option to mkfs.xfs option list
            xfs_opts+="${xfs_param_opt[$i]} $var=$val "
        fi

        i=$((i+1))

    done

  # Output xfs options for further use
  echo "$xfs_opts"
}

# return the total used disk space of the target file systems
function total_target_fs_used_disk_space() {
    # get all mounted file systems for TARGET_FS_ROOT that are mounted on a local device (starting with /)
    # and exclude virtual filesystems like tmpfs, devtmpfs, sysfs, none
    # and return the 3rd column of the last line of the df output that looks like this:
    # Filesystem                         Size  Used Avail Use% Mounted on
    # /dev/mapper/ubuntu--vg-ubuntu--lv  5.6G  4.2G  1.2G  78% /mnt/local
    # /dev/sda2                          1.7G  277M  1.4G  17% /mnt/local/boot
    # /dev/sda1                          537M  6.1M  531M   2% /mnt/local/boot/efi
    # total                              7.8G  4.4G  3.1G  60% -
    #
    # shellcheck disable=SC2046
    df --total --local -h \
        --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=sysfs --exclude-type=none \
        $(mount | sed -n -e "\#^/.*$TARGET_FS_ROOT#s/ .*//p") | sed -E -n -e '$s/[^ ]+ +[^ ]+ +([^ ]+).*/\1/p'
}


# $1 is a mount command argument (string containing comma-separated
# mount options). The remaining arguments to the function ($2 ... )
# specify the mount options to remove from $1, together with a trailing "="
# and any value that follows each option.
# For example, the call
# "remove_mount_options_values nodev,uid=1,rw,gid=1 uid gid"
# returns "nodev,rw".
# There is no support for removing a mount option without a value and "=",
# so "remove_mount_options_values nodev,uid=1,rw,gid=1 rw" will not work.
# The function will return the modified string on stdout.

function remove_mount_options_values () {
    local str="$1"

    shift
    # First add a comma at the end so that it is easier to remove a mount option at the end:
    str="${str/%/,}"
    for i in "$@" ; do
        # FIXME this also removes trailing strings at the end of longer words
        # For example if one wants to remove any id=... option,
        # the function will also replace "uid=1" by "u" by removing
        # the trailing "id=1", which is not intended.
        # Not easy to fix because $str can contain prefixes which are not
        # mount options but arguments to the mount command itself
        # (in particluar, "-o ").
        # FIXME this simple approach would fail in case of mount options
        # containing commas, for example the "context" option values,
        # see mount(8)

        # the extglob shell option is enabled in rear
        str="${str//$i=*([^,]),/}"
    done
    # Remove all commas at the end:
    echo "${str/%,/}"
}
