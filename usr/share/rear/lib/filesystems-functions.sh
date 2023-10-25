# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# File system support functions

function btrfs_subvolume_exists() {
    # returns true if the btrfs subvolume ($2) exists in the Btrfs file system at the mount point ($1).
    local subvolume_mountpoint="$1" btrfs_subvolume_path="$2"

    # A root subvolume can be assumed to always exist
    [ "$btrfs_subvolume_path" == "/" ] && return 0

    # A non-root subvolume exists if the btrfs subvolume list contains its complete path at the end of one line.
    # This code deliberately uses a plain string comparison rather than a regexp.
    btrfs subvolume list -a "$subvolume_mountpoint" | sed -e 's; path <FS_TREE>/; path ;' |
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
