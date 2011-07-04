# Create LVM2 devices
#
# skip if the source system didn't use lvm
test -s "${VAR_DIR}/recovery/lvm/pv_list" || return

LogPrint "Creating the LVM2 devices"

while read DEV VG UUID junk; do
	lvm pvcreate -ff -y -v --restorefile "${VAR_DIR}/recovery/lvm/vgcfgbackup.$VG" -u "${UUID}" "${DEV}" >&8
	StopIfError "Could not create PV $DEV for VG $VG"
done < "${VAR_DIR}/recovery/lvm/pv_list"

for vgfile in "${VAR_DIR}/recovery/lvm/"vgcfgbackup.* ; do
	VG="${vgfile##*vgcfgbackup.}"
	lvm vgcfgrestore -v --file "$vgfile" "$VG" >&8
	StopIfError "Could not restore VG configuration for '$VG'"

	lvm vgchange -v -a y "$VG" >&8
	StopIfError "Could not activate '$VG'"
done

# that's it :-)
