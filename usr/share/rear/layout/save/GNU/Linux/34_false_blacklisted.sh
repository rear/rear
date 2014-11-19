# this script must run after 32_autoexclude.sh; therefore the nr 34_false_blacklisted.sh
# be careful, script 34_generate_mountpoint_device.sh generates the mountpoint devices
# which is used to generate the backup-include.txt file. Therefore, this script must be
# run before 34_generate_mountpoint_device.sh

# check if we have the multipath executable
if ! has_binary multipath ; then
    # no Storage Array Network devices present (most likely)
    return
fi

# sometimes we might see the HP Smart Storage Array disk listed as a multipath device
# Most likely this device was not blacklisted in the blacklist section of the
# /etc/multipath.conf file (do not forget to rebuilt the initial ramdisk after this)
falsempathdev=$( multipath -l | grep "HP,LOGICAL" | awk '{print $1}' )  # mpatha

# if $falsempathdev is empty then we are good and no action needs to be taken
[[ -z "${falsempathdev}" ]]  && return

blockdev=$( get_parent_components  /dev/mapper/mpatha )   # /dev/sdy
if [[ ! -b $blockdev ]]; then
    # not a block device; to be prudent we just return
    return
fi

LogPrint "Multipath device $falsempathdev is part of HP Smart Storage Array and should not be listed as a multipath device"

# save only the devices which were wrongly blacklisted due to the multipath issue
echo "$blockdev" > "$TMP_DIR/blacklisted.devices"
get_child_components "$blockdev" | grep "^/dev" | grep -v "\#orphans" >>  "$TMP_DIR/blacklisted.devices"

while read devname junk ; do
    # we go now over each device listed in the $TMP_DIR/blacklisted.devices file
    # and remove the comment (#) if found in the $LAYOUT_FILE file
    sed -i -e 's|^\#\(.*\) \('$devname' .*\)$|\1 \2|g' "$LAYOUT_FILE"
done < "$TMP_DIR/blacklisted.devices"

