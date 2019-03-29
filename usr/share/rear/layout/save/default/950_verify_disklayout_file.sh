#
# Verify that the entries in disklayout.conf match syntactically
# what is specified in the section "Disk layout file syntax"
# in doc/user-guide/06-layout-configuration.adoc
# cf. https://github.com/rear/rear/issues/2006#issuecomment-460646685
#
# Verify that for each 'disk' the 'part' entries in disklayout.conf
# specify consecutive partition device nodes for the disk
# because otherwise "rear recover" would fail with 'parted' error
#   Error: Partition doesn't exist
# cf. https://github.com/rear/rear/issues/1681
#
# THIS LIMITATION APPLIES TO parted NOT BEING ABLE TO SPECIFY PARTITIONS IN
# BYTES ONLY.
#

LogPrint "Verifying that the entries in $DISKLAYOUT_FILE are correct ..."
local keyword dummy junk

Log "Verifying that the 'disk' entries in $DISKLAYOUT_FILE are correct"
# The section "Disk layout file syntax" in doc/user-guide/06-layout-configuration.adoc reads (excerpt)
#   disk <name> <size(B)> <partition label>
# which is the theory and in practice what matters is what the scripts need that use the 'disk' entries
#   # find usr/share/rear/layout/prepare -type f | xargs grep -l '\^disk'
#   usr/share/rear/layout/prepare/default/300_map_disks.sh
#   usr/share/rear/layout/prepare/default/430_autoresize_all_partitions.sh
#   usr/share/rear/layout/prepare/default/420_autoresize_last_partitions.sh
#   usr/share/rear/layout/prepare/default/250_compare_disks.sh
#   usr/share/rear/layout/prepare/GNU/Linux/100_include_partition_code.sh
# where layout/prepare/GNU/Linux/100_include_partition_code.sh is the most important one
# so that it is used here as reference to decide whether or not the entries are correct:
local broken_disk_errors=()
local disk_dev disk_size parted_mklabel
local broken_part_errors=()
local part_size part_start part_name part_flags part_dev
local partitions=()
local highest_used_part_num part_num
local unused_part_nums=()
local non_consecutive_part_found unused_part_num
local non_consecutive_part_errors=()
local highest_used_mbr_primary_part_num
while read keyword disk_dev disk_size parted_mklabel junk ; do
    test -b "$disk_dev" || broken_disk_errors=( "${broken_disk_errors[@]}" "$disk_dev is not a block device" )
    is_positive_integer $disk_size || broken_disk_errors=( "${broken_disk_errors[@]}" "$disk_dev size $disk_size is not a positive integer" )
    # Here we ignore testing parted_mklabel because create_partitions() in prepare/GNU/Linux/100_include_partition_code.sh has fallbacks

    Log "Verifying that the 'part' entries for $disk_dev in $DISKLAYOUT_FILE are correct"
    # The section "Disk layout file syntax" in doc/user-guide/06-layout-configuration.adoc reads (excerpt)
    #   part <disk name> <size(B)> <start(B)> <partition name/type> <flags/"none"> <partition name>
    # as above layout/prepare/GNU/Linux/100_include_partition_code.sh is the most important one
    # so that it is used here as reference to decide whether or not the entries are correct:
    partitions=()
    while read keyword dummy part_size part_start part_name part_flags part_dev junk ; do
        test -b "$part_dev" || broken_part_errors=( "${broken_part_errors[@]}" "$part_dev is not a block device" )
        is_positive_integer $part_size || broken_part_errors=( "${broken_part_errors[@]}" "$part_dev size $part_size is not a positive integer" )
        is_nonnegative_integer $part_start || broken_part_errors=( "${broken_part_errors[@]}" "$part_dev start $part_start is not a nonnegative integer" )
        partitions=( "${partitions[@]}" "$part_dev" )
        # Using the parted_mklabel fallback behaviour in create_partitions() in prepare/GNU/Linux/100_include_partition_code.sh
        # only when there is no parted_mklabel value, but when there is a parted_mklabel value use it as is:
        if ! test "$parted_mklabel" ; then
            case $part_name in
                (primary|extended|logical)
                    parted_mklabel="msdos"
                    ;;
            esac
        fi
    done < <( grep "^part $disk_dev " "$DISKLAYOUT_FILE" )

    Log "Verifying that the 'part' entries for $disk_dev in $DISKLAYOUT_FILE specify consecutive partitions"
    # The SUSE specific gpt_sync_mbr partitioning scheme is actually a GPT partitioning (plus some compatibility stuff in MBR)
    # see create_partitions() in prepare/GNU/Linux/100_include_partition_code.sh
    test "gpt_sync_mbr" = "$parted_mklabel" && parted_mklabel="gpt"
    # Using the parted_mklabel fallback behaviour in create_partitions() in prepare/GNU/Linux/100_include_partition_code.sh
    # only when there is no parted_mklabel value, but when there is a parted_mklabel value use it as is:
    test "$parted_mklabel" || parted_mklabel="gpt"
    # Determine the highest used partition number:
    highest_used_part_num=0
    for partition in "${partitions[@]}" ; do
        # We test only partitions of the form /dev/sdX1 /dev/sdX2 /dev/sdX3 (i.e. of the form $disk_dev$part_num).
        part_num=${partition#$disk_dev}
        test $part_num -gt $highest_used_part_num && highest_used_part_num=$part_num
    done
    # Skip testing for non consecutive partitions when no highest used partition number > 0 was found
    # because that indicates partitions of another form than /dev/sdX1 /dev/sdX2 /dev/sdX3 are used:
    if test $highest_used_part_num -gt 0 ; then
        case $parted_mklabel in
            (gpt)
                # For the GPT partitioning scheme the partitions must have consecutive numbers 1 2 3 ..
                non_consecutive_part_found=""
                unused_part_nums=()
                for part_num in $( seq $highest_used_part_num ) ; do
                    # Probably there is a better way to implement that as with dumb nested 'for' loops
                    # but note that the partitions in $partitions do not need to be sorted.
                    # Better very simple code than oversophisticated (possibly fragile) constructs
                    # cf. https://github.com/rear/rear/wiki/Coding-Style
                    for partition in "${partitions[@]}" ; do
                        # Partitions that are not of the form $disk_dev$part_num are ignored
                        # so that the test here should not fail for partitions of another form:
                        if test $partition = $disk_dev$part_num ; then
                            # Continue with the next partition number if there is no unused partition up to now:
                            test $unused_part_nums || continue 2
                            # There must not be a partition with higher number than any unused partition number
                            # (the first element in the unused_part_nums array is the lowest unused partition number):
                            test $part_num -gt $unused_part_nums && non_consecutive_part_found="yes"
                            # Continue with the next partition number:
                            continue 2
                        fi
                    done
                    # When no partition with the current number was found remember that the current partition number is unused:
                    unused_part_nums=( "${unused_part_nums[@]}" $part_num )
                done
                if is_true "$non_consecutive_part_found" ; then
                    for unused_part_num in "${unused_part_nums[@]}" ; do
                        non_consecutive_part_errors=( "${non_consecutive_part_errors[@]}" "GPT partitions on $disk_dev not consecutive: $disk_dev$unused_part_num missing" )
                    done
                fi
                ;;
            (msdos)
                # For the MBR partitioning scheme the partitions must not have consecutive numbers.
                # Only primary partitions and a possible extended partition must have consecutive numbers from 1 up to 4.
                # Possible logical partitions must have consecutive numbers 5 6 7 ...
                # There can be a gap between the primary/extended partitions e.g. with number 1 and 2
                # and the logical partitions starting at 5 (there are no partitions with numbers 3 and 4)
                # cf. https://github.com/rear/rear/issues/1681#issue-286345908
                # Testing consecutive partitions from number 1 up to 4 (i.e. testing consecutive primary an extended partitions):
                non_consecutive_part_found=""
                unused_part_nums=()
                # Determine the highest used MBR primary or extended partition number:
                highest_used_mbr_primary_part_num=0
                for partition in "${partitions[@]}" ; do
                    # We test only partitions of the form /dev/sdX1 /dev/sdX2 /dev/sdX3 (i.e. of the form $disk_dev$part_num).
                    part_num=${partition#$disk_dev}
                    # The partitions in $partitions do not need to be sorted so we must test all partitions
                    # and not 'break' the 'for' loop when a partition with partition number > 4 was found:
                    if test $part_num -lt 5 ; then
                        test $part_num -gt $highest_used_mbr_primary_part_num && highest_used_mbr_primary_part_num=$part_num
                    fi
                done
                # Skip testing for non consecutive MBR partitions when no highest used MBR primary or extended partition number > 0 was found:
                if test $highest_used_mbr_primary_part_num -gt 0 ; then
                    for part_num in $( seq $highest_used_mbr_primary_part_num ) ; do
                        for partition in "${partitions[@]}" ; do
                            if test $partition = $disk_dev$part_num ; then
                                test $unused_part_nums || continue 2
                                test $part_num -gt $unused_part_nums && non_consecutive_part_found="yes"
                                continue 2
                            fi
                        done
                        unused_part_nums=( "${unused_part_nums[@]}" $part_num )
                    done
                    if is_true "$non_consecutive_part_found" ; then
                        for unused_part_num in "${unused_part_nums[@]}" ; do
                            non_consecutive_part_errors=( "${non_consecutive_part_errors[@]}" "MBR primary and extended partitions on $disk_dev not consecutive: $disk_dev$unused_part_num missing" )
                        done
                    fi
                    # Testing consecutive partitions starting at 5 (i.e. testing consecutive logical partitions):
                    non_consecutive_part_found=""
                    unused_part_nums=()
                    for part_num in $( seq 5 $highest_used_part_num ) ; do
                        for partition in "${partitions[@]}" ; do
                            if test $partition = $disk_dev$part_num ; then
                                test $unused_part_nums || continue 2
                                test $part_num -gt $unused_part_nums && non_consecutive_part_found="yes"
                                continue 2
                            fi
                        done
                        unused_part_nums=( "${unused_part_nums[@]}" $part_num )
                    done
                    if is_true "$non_consecutive_part_found" ; then
                        for unused_part_num in "${unused_part_nums[@]}" ; do
                            non_consecutive_part_errors=( "${non_consecutive_part_errors[@]}" "MBR logical partitions on $disk_dev not consecutive: $disk_dev$unused_part_num missing" )
                        done
                    fi
                fi
                ;;
            (*)
                broken_disk_errors=( "${broken_disk_errors[@]}" "$disk_dev partitioning scheme '$parted_mklabel' is neither 'gpt' nor 'msdos'" )
                ;;
        esac
    fi

done < <( grep "^disk " "$DISKLAYOUT_FILE" )


# Finally after all tests had been done (so that the user gets all result messages) error out if needed:

# It is a BugError when at this stage the entries in disklayout.conf are broken
# because just before this script the entries in disklayout.conf were created
# by various 'layout/save' scripts where each of those 'layout/save' scripts should error out
# when it cannot create a valid entry (e.g. because of whatever reasons outside of ReaR).
local disklayout_file_is_broken=""
local non_consecutive_partitions=""
local error_message
for error_message in "${broken_disk_errors[@]}" ; do
    contains_visible_char "$error_message" || continue
    LogPrintError "$error_message"
    disklayout_file_is_broken="yes"
done
for error_message in "${broken_part_errors[@]}" ; do
    contains_visible_char "$error_message" || continue
    LogPrintError "$error_message"
    disklayout_file_is_broken="yes"
done

#
# Non consecutive partitions are supported unless parted tells otherwise
#
if is_false $FEATURE_PARTED_RESIZEPART && is_false $FEATURE_PARTED_RESIZE ; then
    for error_message in "${non_consecutive_part_errors[@]}" ; do
        contains_visible_char "$error_message" || continue
        LogPrintError "$error_message"
        non_consecutive_partitions="yes"
    done
fi

is_true "$disklayout_file_is_broken" && BugError "Entries in $DISKLAYOUT_FILE are broken ('rear recover' would fail)"

is_true "$non_consecutive_partitions" && Error "There are non consecutive partitions ('rear recover' would fail)"

# Finish this script successfully in the normal case (i.e. when both 'is_true' above result non zero return code):
true

# vim: set et ts=4 sw=4:
