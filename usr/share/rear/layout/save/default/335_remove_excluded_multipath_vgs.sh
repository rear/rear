# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# If AUTOEXCLUDE_MULTIPATH=n is used in combination with ONLY_INCLUDE_VG or
# EXCLUDE_VG then the exclusion is not done at multipath devices - this
# script tries to fix this

if is_true $AUTOEXCLUDE_MULTIPATH ; then
    # If all multipath devices are automatically excluded then there is no need
    # to further investigate if EXCLUDE_VG or ONLY_INCLUDE_VG was respected for multipath devices:
    return
fi

while read lvmdev name mpdev junk ; do
    # We inspect entries of 'excluded' VGs and are now interested in the multipath devices
    # instead of the /dev/VG - an entry looks like:
    # #lvmdev /dev/h50l050vg00 /dev/mapper/360060e8007e2e3000030e2e30000449f2 Nn3ew5-Wkve-FpSY-mgng-3T0l-rSz1-EEvPrE 502288384
    # We need to 'cut -c1-45' (third arg) to grab the full multipath device and not only a partition
    # Remember, multipath devices from a volume group that is "excluded" should be 'commented out'
    device=$(echo $mpdev | cut -c1-45)
    while read LINE ; do
        # Now we need to comment all lines that contain "$device" in the LAYOUT_FILE
        sed -i "s|^$LINE|\#$LINE|" "$LAYOUT_FILE"
    done < <(grep " $device " $LAYOUT_FILE | grep -v "^#")
    DebugPrint "Disabling multipath device $device belonging to disabled 'lvmdev $name' in $LAYOUT_FILE"
done < <(grep "^#lvmdev" $LAYOUT_FILE)

# Double check if we did not leave unused multipath devices uncommented
# We should only keep 'uncommented' multipath devices used by a 'lvmdev' line
# This is the case when multipath devices are visible, but not in use a Volume Group (spare/empty devices)
while read LINE ; do
    # multipath /dev/mapper/360060e8007e2e3000030e2e300002065 /dev/sdae,/dev/sdat,/dev/sdbi,/dev/sdp
    device=$(echo $LINE | awk '{print $2}' | cut -c1-45)
    num=$(grep " $device " $LAYOUT_FILE | grep -v "^#" | wc -l)
    if [ $num -lt 2 ] ; then
        # If the $device is only seen once (in a uncommented line) then the multipath is not in use
        sed -i "s|^$LINE|\#$LINE|" "$LAYOUT_FILE"
        DebugPrint "Disabling multipath device $device only seen once in $LAYOUT_FILE"
    fi
done < <(grep "^multipath" $LAYOUT_FILE)
