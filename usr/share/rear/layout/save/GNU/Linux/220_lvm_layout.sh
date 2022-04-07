# Save LVM layout

# TODO: What if there are logical volumes on the system but there is no 'lvm' binary?
# Shouldn't then "rear mkrescue" better error out here than to silently skip LVM altogether?
# Cf. "Try hard to care about possible errors" in https://github.com/rear/rear/wiki/Coding-Style
# Think about a minimal system that was set up by a (full featured) installation system
# but tools to set up things were not installed in the (now running) installed system.
# For example 'parted' is usually no longer needed in the installed system.
# Perhaps this cannot happen for LVM so an 'lvm' binary must exist when LVM is used?
has_binary lvm || return 0

Log "Begin saving LVM layout ..."

local header_printed
local pdev vgrp size uuid pvdisplay_exit_code
local extentsize nrextents vgdisplay_exit_code
local already_processed_lvs=()
local lv_layout_supported lvs_fields
local origin lv vg
local layout modules
local thinpool chunksize stripes stripesize segmentsize
local kval infokval
local lvs_exit_code

# General explanation why in this script we use pipes of the form
#   COMMAND | while read ... do ... done
# instead of how we usually do it via bash process substitution of the form
#   while read ... do ... done < <( COMMAND )
# The reason is that in case of process substitution COMMAND seems to be run "very asynchronously"
# where it seems it is not possible (in a simple and clean way) to get the exit status of COMMAND.
# At least not with bash version 3.2.57 on SLES11-SP4 and not with bash version 4.3.42 on SLES12-SP4
# where I <jsmeix@suse.de> get with both bash versions the same "always failed with exit status 127" result:
#   # while read line ; do echo $line ; done < <( pstree -Aplau $$ ) ; wait $! && echo OK || echo FAILED with $?
#   bash,885
#   `-bash,5627
#   `-pstree,5628 -Aplau 885
#   -bash: wait: pid 5627 is not a child of this shell
#   FAILED with 127
#   # while read line ; do echo $line ; done < <( echo | grep -Q foo ) ; wait $! && echo OK || echo FAILED with $?
#   grep: invalid option -- 'Q'
#   -bash: wait: pid 6030 is not a child of this shell
#   FAILED with 127
# This looks like a bug in bash at least up to version 4.3.42 because I think
# pstree correctly reports pid 5627 as a child of pid 885 in contrast to what bash reports.
# It seems that works with bash version 4.4.23 on openSUSE Leap 15.0 where I get:
#   # while read line ; do echo $line ; done < <( pstree -Aplau $$ ) ; wait $! && echo OK || echo FAILED with $?
#   bash,5821
#   `-bash,14287
#   `-pstree,14288 -Aplau 5821
#   OK
#   # while read line ; do echo $line ; done < <( echo | grep -Q foo ) ; wait $! && echo OK || echo FAILED with $?
#   grep: invalid option -- 'Q'
#   FAILED with 2
# Because ReaR must work with bash version 3.x we cannot use 'wait $!' to get
# the exit status of a COMMAND that is run asynchronously via process substitution.
# In contrast for a pipe ${PIPESTATUS[0]} provides the exit status of its first command
# (in contrast to $? that provides the exit status of the last command in a pipe
#  unless 'set -o pipefail' is set which lets $? provide the exit status of
#  the last command in a pipe that failed - or 0 if none failed - so $? does
#  not provide a reliable way to get the exit status of the first command in a pipe).
# The drawback of using a pipe is that the "while read ... do ... done" part
# is run as separated process (in a subshell) so that e.g. one cannot set variables
# in the "while read ... do ... done" part that are meant to be used after the pipe.
# In contrast with the process substitution method the "while read ... do ... done" part
# runs in the current shell (but then COMMAND seems to be somewhat "out of control").

# Begin of group command that appends its stdout to DISKLAYOUT_FILE:
{

    # Get physical_device configuration.
    # Format: lvmdev <volume_group> <device> [<uuid>] [<size(bytes)>]
    header_printed="no"
    # Example output of "lvm pvdisplay -c":
    #   /dev/sda1:system:41940992:-1:8:8:-1:4096:5119:2:5117:7wwpcO-KmNN-qsTE-7sp7-JBJS-vBdC-Zyt1W7
    # There are two leading blanks in the output (at least on SLES12-SP4 with LVM 2.02.180).
    lvm pvdisplay -c | while read line ; do

        # With the above example pdev=/dev/sda1
        # (the "echo $line" makes the leading blanks disappear)
        pdev=$( echo $line | cut -d ":" -f "1" )

        # Skip lines that are not describing physical devices
        # i.e. lines where pdev does not start with a leading / character:
        test "${pdev#/}" = "$pdev" && continue

        # Output lvmdev header only once to DISKLAYOUT_FILE:
        if is_false $header_printed ; then
            echo "# Format for LVM PVs"
            echo "# lvmdev <volume_group> <device> [<uuid>] [<size(bytes)>]"
            header_printed="yes"
        fi

        # With the above example vgrp=system
        vgrp=$( echo $line | cut -d ":" -f "2" )
        # With the above example size=41940992
        size=$( echo $line | cut -d ":" -f "3" )
        # With the above example uuid=7wwpcO-KmNN-qsTE-7sp7-JBJS-vBdC-Zyt1W7
        uuid=$( echo $line | cut -d ":" -f "12" )

        # Translate pdev through diskbyid_mappings file:
        pdev=$( get_device_mapping $pdev )
        # Translate a sysfs name or device name to the name preferred in ReaR:
        pdev=$( get_device_name $pdev )

        # Output lvmdev entry to DISKLAYOUT_FILE:
        # Check that the required positional parameters in the 'lvmdev' line are non-empty
        # because an empty positional parameter would result an invalid 'lvmdev' line
        # which would cause invalid parameters are 'read' as input during "rear recover"
        # cf. "Verifying ... 'lvm...' entries" in layout/save/default/950_verify_disklayout_file.sh
        # The variables are not quoted because plain 'test' without argument results non-zero exit code
        # and 'test foo bar' fails with "bash: test: foo: unary operator expected"
        # so that this also checks that the variables do not contain blanks or more than one word
        # because blanks (actually $IFS characters) are used as field separators in disklayout.conf
        # which means the positional parameter values must be exactly one non-empty word.
        test $pdev || Error "Cannot make 'lvmdev' entry in disklayout.conf (PV device '$pdev' empty or more than one word)"
        if ! test $vgrp ; then
            # Valid $pdev but invalid $vgrp (empty or more than one word):
            # When $vgrp is empty it means it is a PV that is not part of a VG so the PV exists but it is not used.
            # PVs that are not part of a VG are documented as comment in disklayout.conf but they are not recreated
            # because they were not used on the original system so there is no need to recreate them by "rear recover"
            # (the user can manually recreate them later in his recreated system when needed)
            # cf. https://github.com/rear/rear/issues/2596
            DebugPrint "Skipping PV $pdev that is not part of a valid VG (VG '$vgrp' empty or more than one word)"
            echo "# Skipping PV $pdev that is not part of a valid VG (VG '$vgrp' empty or more than one word):"
            contains_visible_char "$vgrp" || vgrp='<missing_VG>'
            echo "# lvmdev /dev/$vgrp $pdev $uuid $size"
            # Continue with the next line in the output of "lvm pvdisplay -c"
            continue
        fi
        # With the above example the output is:
        # lvmdev /dev/system /dev/sda1 7wwpcO-KmNN-qsTE-7sp7-JBJS-vBdC-Zyt1W7 41940992
        echo "lvmdev /dev/$vgrp $pdev $uuid $size"

    done
    # Check the exit code of "lvm pvdisplay -c"
    # in the "lvm pvdisplay -c | while read line ; do ... done" pipe:
    pvdisplay_exit_code=${PIPESTATUS[0]}
    test $pvdisplay_exit_code -eq 0 || Error "LVM command 'lvm pvdisplay -c' failed with exit code $pvdisplay_exit_code"

    # Get the volume group configuration:
    # Format: lvmgrp <volume_group> <extentsize> [<size(extents)>] [<size(bytes)>]
    header_printed="no"
    # Example output of "lvm vgdisplay -c":
    #   system:r/w:772:-1:0:2:2:-1:0:1:1:20967424:4096:5119:5117:2:lqIC4T-u5KW-f57o-TpIZ-AYxD-rm3f-06sa6J
    # There are two leading blanks in the output (at least on SLES12-SP4 with LVM 2.02.180).
    lvm vgdisplay -c | while read line ; do
        # With the above example vgrp=system
        # (the "echo $line" makes the leading blanks disappear)
        vgrp=$( echo $line | cut -d ":" -f "1" )
        # With the above example size=20967424
        # ( size = 20967424 = 4096 * 5119 = extentsize * nrextents )
        size=$( echo $line | cut -d ":" -f "12" )
        # With the above example extentsize=4096
        extentsize=$( echo $line | cut -d ":" -f "13" )
        # With the above example nrextents=5119
        nrextents=$( echo $line | cut -d ":" -f "14" )

        # Output lvmgrp header only once to DISKLAYOUT_FILE:
        if is_false $header_printed ; then
            echo "# Format for LVM VGs"
            echo "# lvmgrp <volume_group> <extentsize> [<size(extents)>] [<size(bytes)>]"
            header_printed="yes"
        fi

        # Output lvmgrp entry to DISKLAYOUT_FILE:
        # With the above example the output is:
        # lvmgrp /dev/system 4096 5119 20967424
        echo "lvmgrp /dev/$vgrp $extentsize $nrextents $size"

        # Check that the required positional parameters in the 'lvmgrp' line are non-empty.
        # The tested variables are intentionally not quoted here, cf. the code above to
        # "check that the required positional parameters in the 'lvmdev' line are non-empty".
        # Two separated simple 'test $vgrp && test $extentsize' commands are used here because
        # 'test $vgrp -a $extentsize' does not work when $vgrp is empty or only blanks
        # because '-a' has two different meanings: "EXPR1 -a EXPR2" and "-a FILE" (see "help test")
        # so with empty $vgrp it becomes 'test -a $extentsize' that tests if a file $extentsize exists
        # which is unlikely to be true but it is not impossible that a file $extentsize exists
        # so when $vgrp is empty (or blanks) 'test $vgrp -a $extentsize' might falsely succeed:
        test $vgrp && test $extentsize || Error "LVM 'lvmgrp' entry in $DISKLAYOUT_FILE where volume_group or extentsize is empty or more than one word"

    done
    # Check the exit code of "lvm vgdisplay -c"
    # in the "lvm vgdisplay -c | while read line ; do ... done" pipe:
    vgdisplay_exit_code=${PIPESTATUS[0]}
    test $vgdisplay_exit_code -eq 0 || Error "LVM command 'lvm vgdisplay -c' failed with exit code $vgdisplay_exit_code"

    # Get all logical volumes:
    # Format: lvmvol <volume_group> <name> <size(bytes)> <layout> [key:value ...]
    header_printed="no"
    already_processed_lvs=()

    # Check for 'lvs' support of the 'lv_layout' field:
    lvm lvs -o lv_layout &>/dev/null && lv_layout_supported="yes" || lv_layout_supported="no"

    # Specify the fields for the lvs command depending on whether or not the 'lv_layout' field is supported:
    if is_true $lv_layout_supported ; then
        lvs_fields="origin,lv_name,vg_name,lv_size,lv_layout,pool_lv,chunk_size,stripes,stripe_size,seg_size"
    else
        # Use the 'modules' field as fallback replacement when the 'lv_layout' field is not supported:
        lvs_fields="origin,lv_name,vg_name,lv_size,modules,pool_lv,chunk_size,stripes,stripe_size,seg_size"
    fi

    # Example output of "lvs --separator=':' --noheadings --units b --nosuffix -o $lvs_fields"
    # with lvs_fields="origin,lv_name,vg_name,lv_size,lv_layout,pool_lv,chunk_size,stripes,stripe_size,seg_size"
    # i.e. when the 'lv_layout' field is supported:
    
    #   :home:system:6148849664:linear::0:1:0:6148849664
    #   :root:system:14050918400:linear::0:1:0:14050918400
    #   :swap:system:1262485504:linear::0:1:0:1262485504
    # There are two leading blanks in the output (at least on SLES12-SP4 with LVM 2.02.180 and SLES15-SP3 with LVM 2.03.05).
    # The 'lvs' output lines ordering does not match the ordering of the LVs kernel device nodes /dev/dm-N
    #   # lsblk -ipbo NAME,KNAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/sda2
    #   NAME                      KNAME     TYPE FSTYPE             SIZE MOUNTPOINT
    #   /dev/sda2                 /dev/sda2 part LVM2_member 21465382400
    #   |-/dev/mapper/system-swap /dev/dm-0 lvm  swap         1262485504 [SWAP]
    #   |-/dev/mapper/system-root /dev/dm-1 lvm  btrfs       14050918400 /
    #   `-/dev/mapper/system-home /dev/dm-2 lvm  xfs          6148849664 /home
    # This means during "rear recover" the LVs would get recreated according to the ordering of the 'lvs' output lines
    # because during "rear recover" LVs get recreated according to the ordering of the 'lvmvol' lines in disklayout.conf
    # so the recreated LVs get different kernel device nodes /dev/dm-N compared to what there was on the original system.
    # This did not cause any issue at ReaR so far so it seems safe to assume it does not matter in practice
    # what kernel device node /dev/dm-0 /dev/dm-1 /dev/dm-2 belongs to the LVs
    # because in practice LVs seem to be always accessed via their symlinks
    # /dev/mapper/system-swap /dev/mapper/system-root /dev/mapper/system-home
    # cf. https://github.com/rear/rear/pull/2291#issuecomment-567933705
    # Therefore we can re-order the 'lvs' output lines as we need it to make "rear recover" behave more fail safe
    # when it is run on a bit smaller replacement disk(s) so one or more LVs need to be automatically shrinked a bit.
    # The automated LVs shrinking is not intended when replacement disk(s) are substantially smaller.
    # To migrate onto a substantially smaller replacement disk the user must in advance
    # manually adapt his disklayout.conf file before he runs "rear recover".
    # The basic idea to automatically shrink LVs is to implement a "minimal changes" approach
    # cf. "minimal changes" in layout/prepare/default/420_autoresize_last_partitions.sh
    # where the "minimal changes" approach is here to only shrink one single LV per disk if needed.
    # A LV needs to be shrinked only if it is not possible to recreate all LVs with their specified size
    # i.e. when during "rear recover" 'lvcreate' fails with "Volume group ... has insufficient free space".
    # In this case 'lvcreate' is called again where the exact size option of the form '-L 123456b'
    # is replaced with an option to use all remaining free space in the VG via '-l 100%FREE'
    # so e.g. 'lvcreate -L 123456b -n LV VG' becomes 'lvcreate -l 100%FREE -n LV VG'
    # see layout/prepare/GNU/Linux/110_include_lvm_code.sh
    # The most reasonable LVs that can be shrinked a bit with a "minimal changes" approach are the biggest LVs
    # because we assume that the data of the backup can still be restored into a big LV after it was shrinked a bit.
    # So we sort the 'lvs' output lines by the size of the LVs (4th field in the output lines, 1st field is two blanks)
    # so that the biggest LVs get listed last in disklayout.conf and get recreated last during "rear recover"
    # so 'lvcreate' may only fail with "Volume group ... has insufficient free space" for some of the biggest LVs.
    # Additionally it had happened during my <jsmeix@suse.de> initial tests that shrinking the 'swap' LV somehow caused
    # that the recreated system did not boot (boot screen showed GRUB but there it hung with constant 100% CPU usage)
    # so automatically shrinking only the biggest LVs avoids that a relatively small 'swap' LV gets shrinked.
    # With 'sort -n -t ':' -k 4' the above 'lvs' output lines become
    #   :swap:system:1262485504:linear::0:1:0:1262485504
    #   :home:system:6148849664:linear::0:1:0:6148849664
    #   :root:system:14050918400:linear::0:1:0:14050918400
    # so only the 'root' LV may get automatically shrinked if needed.
    lvm lvs --separator=':' --noheadings --units b --nosuffix -o $lvs_fields | sort -n -t ':' -k 4 | while read line ; do

        # Output lvmvol header only once to DISKLAYOUT_FILE:
        if is_false $header_printed ; then
            echo "# Format for LVM LVs"
            echo "# lvmvol <volume_group> <name> <size(bytes)> <layout> [key:value ...]"
            header_printed="yes"
        fi

        # With the above example origin=""
        # (the "echo $line" makes the leading blanks disappear)
        origin="$( echo "$line" | awk -F ':' '{ print $1 }' )"
        # Skip snapshots (useless) or caches (dont know how to handle that)
        if test "$origin" ; then
            echo "# Skipped snapshot or cache information '$line'"
            continue
        fi

        # With the above example lv=root and lv=swap
        lv="$( echo "$line" | awk -F ':' '{ print $2 }' )"

        # With the above example vg=system
        vg="$( echo "$line" | awk -F ':' '{ print $3 }' )"

        # With the above example size=19927138304 and size=1535115264
        size="$( echo "$line" | awk -F ':' '{ print $4 }' )"

        if is_true $lv_layout_supported ; then
            # With the above example layout=linear
            layout="$( echo "$line" | awk -F ':' '{ print $5 }' )"
        else
            modules="$( echo "$line" | awk -F ':' '{ print $5 }' )"
        fi

        # With the above example thinpool=""
        thinpool="$( echo "$line" | awk -F ':' '{ print $6 }' )"

        # With the above example chunksize=0
        chunksize="$( echo "$line" | awk -F ':' '{ print $7 }' )"

        # With the above example stripes=1
        stripes="$( echo "$line" | awk -F ':' '{ print $8 }' )"

        # With the above example stripesize=0
        stripesize="$( echo "$line" | awk -F ':' '{ print $9 }' )"

        # With the above example segmentsize=19927138304 and segmentsize=1535115264
        segmentsize="$( echo "$line" | awk -F ':' '{ print $10 }' )"

        # TODO: Explain what that code is meant to do.
        # In particular a more explanatory variable name than 'kval' might help.
        # In 110_include_lvm_code.sh there is a comment what 'kval' means there
        #   # kval: "key:value" pairs, separated by spaces
        # so probably 'kval' means the same here, but what is 'infokval'?
        kval=""
        infokval=""
        [ -z "$thinpool" ] || kval="${kval:+$kval }thinpool:$thinpool"
        [ $chunksize -eq 0 ] || kval="${kval:+$kval }chunksize:${chunksize}b"
        [ $stripesize -eq 0 ] || kval="${kval:+$kval }stripesize:${stripesize}b"
        [ $segmentsize -eq $size ] || infokval="${infokval:+$infokval }segmentsize:${segmentsize}b"

        # TODO: Explain what that code is meant to do:
        if is_true $lv_layout_supported ; then
            # TODO: Explain what that code is meant to do:
            if [[ ,$layout, == *,mirror,* ]] ; then
                kval="${kval:+$kval }mirrors:$(($stripes - 1))"
            elif [[ ,$layout, == *,striped,* ]] ; then
                kval="${kval:+$kval }stripes:$stripes"
            fi
        else
            # TODO: Explain what that code is meant to do:
            if [[ "$modules" == "" ]] ; then
                layout="linear"
                [ $stripes -eq 0 ] || kval="${kval:+$kval }stripes:$stripes"
            elif [[ ,$modules, == *,mirror,* ]] ; then
                layout="mirror"
                kval="${kval:+$kval }mirrors:$(($stripes - 1))"
            elif [[ ,$modules, == *,thin-pool,* ]] ; then
                if [ -z "$thinpool" ] ; then
                    layout="thin,pool"
                else
                    layout="thin,sparse"
                fi
            elif [[ ,$modules, == *,raid,* ]] ; then
                LogPrintError "LVM: Collecting RAID information for LV '$lv' unsupported ('lv_layout' field not supported). Automatic disk layout recovery may fail."
                layout="raid,RAID_UNKNOWNTYPE"
                kval="${kval:+$kval }stripes:$stripes"
            fi
        fi

        # Output lvmvol entry to DISKLAYOUT_FILE:
        if IsInArray "$vg/$lv" "${already_processed_lvs[@]}" ; then
            # The LV has multiple segments.
            # The create_lvmvol() function in 110_include_lvm_code.sh is not able to recreate this.
            # But we keep the information for the administrator anyway:
            echo "#lvmvol /dev/$vg $lv ${size}b $layout $kval"
            if [ -n "$infokval" ] ; then
                echo "# Extra parameters for the '#lvmvol /dev/$vg $lv' line above not taken into account when restoring using 'lvcreate': $infokval"
            fi
        else
            if [ $segmentsize -ne $size ] ; then
                echo "# Volume $vg/$lv has multiple segments. Recreating it by 'lvcreate' will not preserve segments and properties of the other segments as well"
            fi
            # With the above example the output is:
            # lvmvol /dev/system root 19927138304b linear
            # lvmvol /dev/system swap 1535115264b linear
            echo "lvmvol /dev/$vg $lv ${size}b $layout $kval"
            if [ -n "$infokval" ] ; then
                echo "# Extra parameters for the 'lvmvol /dev/$vg $lv' line above not taken into account when restoring using 'lvcreate': $infokval"
            fi
            already_processed_lvs+=( "$vg/$lv" )
            # Check that the required positional parameters in the 'lvmvol' line are non-empty
            # cf. the code above to "check that the required positional parameters in the 'lvmdev' line are non-empty"
            # and the code above to "check that the required positional parameters in the 'lvmgrp' line are non-empty":
            test $vg && test $lv && test $size && test $layout || Error "LVM 'lvmvol' entry in $DISKLAYOUT_FILE where volume_group or name or size or layout is empty or more than one word"
        fi

    done
    # Check the exit code of "lvm lvs --separator=':' --noheadings --units b --nosuffix -o $lvs_fields"
    # in the "lvm lvs --separator=':' --noheadings --units b --nosuffix -o $lvs_fields | while read line ; do ... done" pipe:
    lvs_exit_code=${PIPESTATUS[0]}
    test $lvs_exit_code -eq 0 || Error "LVM command 'lvs ... -o $lvs_fields' failed with exit code $lvs_exit_code"

} 1>>$DISKLAYOUT_FILE
# End of group command that appends its stdout to DISKLAYOUT_FILE

Log "End saving LVM layout"

# 'lvm' is required in the recovery system if disklayout.conf contains at least one 'lvmdev' or 'lvmgrp' or 'lvmvol' entry
# see the create_lvmdev create_lvmgrp create_lvmvol functions in layout/prepare/GNU/Linux/110_include_lvm_code.sh
# what program calls are written to diskrestore.sh
# cf. https://github.com/rear/rear/issues/1963
egrep -q '^lvmdev |^lvmgrp |^lvmvol ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( lvm ) || true

# vim: set et ts=4 sw=4:

